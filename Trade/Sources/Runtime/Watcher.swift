import Foundation
import OrderedCollections
import Brokerage
import Persistence
import TradingStrategy
import TradeWithIt
import SwiftUI

@Observable
public class Watcher: Identifiable {
    public private(set) var contract: any Contract
    public private(set) var quote: Quote?
    public private(set) var interval: TimeInterval
    public private(set) var strategy: Strategy
    public private(set) var activeTrade: Trade? = nil

    private let userInfo: [String: Any]
    private let strategyType: Strategy.Type
    private var candles: OrderedSet<Bar> {
        OrderedSet((strategy.candles as? [Bar]) ?? [])
    }
    
    private var maxCandlesCount: Int {
        let targetIntervals: [TimeInterval] = [900.0, 3600.0, 7200.0]
        let multiplier = targetIntervals.first(where: { $0 > interval }).map { Int($0 / interval) } ?? 1
        return 200 * multiplier
    }
    
    public var symbol: String { contract.symbol }
    public var id: String { "\(contract.label):\(interval)" }
    public var displayName: String { "\(symbol): \(interval.formatCandleTimeInterval())" }
    
    private var quoteTask: Task<Void, Never>?
    private var marketDataTask: Task<Void, Never>?
    private var marketOrder: MarketOrder?
    public private(set) var tradingHours: [TradingHour] = [] {
        didSet {
            print("🕖", contract.symbol, self.tradingHours.isMarketOpen())
        }
    }
    
    deinit {
        marketOrder = nil
        quoteTask?.cancel()
        marketDataTask?.cancel()
    }

    public init(
        contract: any Contract,
        interval: TimeInterval,
        strategyType: Strategy.Type = SupriseBarStrategy.self,
        marketData: MarketData,
        fileProvider: CandleFileProvider,
        userInfo: [String: Any] = [:]
    ) throws {
        self.contract = contract
        self.interval = interval
        self.userInfo = userInfo
        self.strategyType = strategyType
        self.strategy = strategyType.init(candles: [])
        
        quoteTask = Task { await self.setupMarketQuoteData(market: marketData) }
        marketDataTask = Task { await self.setupMarketData(marketData: marketData, fileProvider: fileProvider) }
        fetchTredingHours(marketData: marketData)
    }
    
    public func saveCandles(fileProvider: CandleFileProvider) {
        guard !strategy.candles.isEmpty else { return }
        snapshotData(fileProvider: fileProvider, candles: strategy.candles)
    }
    
    public func fetchTredingHours(marketData: MarketData) {
        Task {
            let hours = try await marketData.tradingHour(contract)
            await MainActor.run {
                self.tradingHours = hours
            }
        }
    }
    
    private func setupMarketQuoteData(market: MarketData) async {
        do {
            for await newQuote in try market.quotePublisher(contract: contract).values {
                await MainActor.run {
                    if var existingQuote = self.quote {
                        switch newQuote.type {
                        case .bidPrice:
                            existingQuote.bidPrice = newQuote.value
                        case .askPrice:
                            existingQuote.askPrice = newQuote.value
                        case .lastPrice:
                            existingQuote.lastPrice = newQuote.value
                        case .volume:
                            existingQuote.volume = newQuote.value
                        case .none:
                            break
                        }
                        existingQuote.date = Date()
                        self.quote = existingQuote
                    } else {
                        self.quote = Quote(
                            contract: contract,
                            date: Date(),
                            bidPrice: newQuote.type == .bidPrice ? newQuote.value : nil,
                            askPrice: newQuote.type == .askPrice ? newQuote.value : nil,
                            lastPrice: newQuote.type == .lastPrice ? newQuote.value : nil,
                            volume: newQuote.type == .volume ? newQuote.value : nil
                        )
                    }
                }
            }
        } catch {
            print("Quote stream error: \(error)")
        }
    }
    
    private func setupMarketData(marketData: MarketData, fileProvider: CandleFileProvider) async {
        do {
            var updatedUserInfo = userInfo
            updatedUserInfo[MarketDataKey.bufferInfo.rawValue] = interval * Double(maxCandlesCount) * 2.0
            var lastEmissionTime: Date? = nil
            
            for await candlesData in try marketData.marketData(
                contract: contract,
                interval: interval,
                userInfo: updatedUserInfo
            ).values {
                if Task.isCancelled { break }
                
                // Throttle if needed (200ms unless marketData is a file provider)
                if !(marketData is MarketDataFileProvider) {
                    let now = Date()
                    if let last = lastEmissionTime, now.timeIntervalSince(last) < 0.2 {
                        continue
                    }
                    lastEmissionTime = now
                }
                
                let bars = updateBars(candlesData.bars)
                let strat = updateStrategy(bars: bars)
                
                enterTradeIfStrategyIsValidated(strategy: strat)
                manageActiveTrade(strategy: strat)
                await MainActor.run { self.strategy = strat }
            }
        } catch {
            print("Market data stream error: \(error)")
        }
    }
    
    private func snapshotData(fileProvider: CandleFileProvider, candles: [any Klines]) {
        guard let bars = candles as? [Bar] else { return }
        do {
            try fileProvider.save(
                symbol: contract.symbol,
                interval: interval,
                bars: bars,
                strategyName: String(describing: strategyType)
            )
        } catch {
            print("🔴 Failed to save snapshot data for:", id)
        }
    }
    
    private func updateBars(_ bars: [Bar]) -> [Bar] {
        var currentCandles = self.candles
        if currentCandles.isEmpty {
            currentCandles = OrderedSet(bars)
        } else {
            for bar in bars {
                if let index = currentCandles.lastIndex(of: bar) {
                    currentCandles.update(bar, at: index)
                } else if let lastBar = currentCandles.last, bar.timeOpen > lastBar.timeOpen {
                    currentCandles.updateOrAppend(bar)
                }
            }
        }
        if currentCandles.count > maxCandlesCount {
            currentCandles.removeFirst(currentCandles.count - maxCandlesCount)
        }
        return Array(currentCandles)
    }
    
    private func updateStrategy(bars: [Bar]) -> any Strategy {
        strategyType.init(candles: bars)
    }
    
    private func enterTradeIfStrategyIsValidated(strategy: (any Strategy)?) {
        guard
            let account = marketOrder?.account,
            let strategy, strategy.patternIdentified,
            let entryBar = strategy.candles.last
        else { return }
        
        // 5 sec before bar closes
        print("✅ enterTradeIfStrategyIsValidated interval: ", Date().timeIntervalSince1970 >= (entryBar.timeClose - 5))
        guard Date().timeIntervalSince1970 >= (entryBar.timeClose - 5) else { return }
        
        saveTradeRecordEntrySnapshot(entryBar: entryBar, buyingPower: account.buyingPower)
        
        let units = strategy.unitCount(equity: account.buyingPower, feePerUnit: 50)
        print("✅ enterTradeIfStrategyIsValidated units: ", units)
        guard units > 0 else { return }
        
        print("✅ enterTradeIfStrategyIsValidated stopLoss: ", strategy.adjustStopLoss(entryBar: entryBar))
        guard let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar) else { return }
        
        evaluateMarketCoonditions(trade: Trade(
            entryBar: entryBar,
            price: entryBar.priceClose,
            trailStopPrice: initialStopLoss,
            units: Double(units)
        ))
    }
    
    private func saveTradeRecordEntrySnapshot(entryBar: any Klines, buyingPower: Double) {
        print("💿 Saving trade record entry snapshot...")
        Task {
            let trade = TradeRecord(
                id: UUID(),
                symbol: contract.symbol,
                strategy: String(describing: strategyType),
                entryPrice: entryBar.priceClose,
                buyingPowerOnEntry: buyingPower,
                entryTime: Date(),
                decision: entryBar.isLong ? "Long" : "Short",
                entrySnapshot: strategy.candles.map { Candle(from: $0) },
                exitSnapshot: nil
            )
            
            PersistenceManager.shared.saveTrade(trade)
        }
    }
    
    private func evaluateMarketCoonditions(trade: Trade) {
        // TODO: 1. Check for market alerts
        
        // Is market open during liquid hours
        let marketOpen = tradingHours.isMarketOpen()
        print("✅ evaluateMarketCoonditions: ", marketOpen)
        guard
            marketOpen.isOpen,
            let timeUntilClose = marketOpen.timeUntilChange,
            // 30 min before market close
            timeUntilClose > (1_800 * 6)
        else { return }
        
        self.activeTrade = trade
        do {
            print("✅✅ enter trade: ", trade)
            try marketOrder?.makeLimitWithTrailingStopOrder(
                contract: contract,
                action: trade.entryBar.isLong ? .buy : .sell,
                price: trade.price,
                trailStopPrice: trade.trailStopPrice,
                quantity: trade.units
            )
        } catch {
            print("Something went wrong while exiting trade: \(error)")
        }
    }
    
    private func manageActiveTrade(strategy: (any Strategy)) {
        guard let activeTrade, let account = marketOrder?.account else { return }
        guard strategy.shouldExit(entryBar: activeTrade.entryBar) else { return }
        guard let position = account.positions.first(where: { $0.label == contract.label }) else { return }
        do {
            try marketOrder?.makeLimitOrder(
                contract: contract,
                action: activeTrade.entryBar.isLong ? .sell : .buy,
                price: position.averageCost,
                quantity: position.quantity
            )
            self.activeTrade = nil
        } catch {
            print("Something went wrong while exiting trade: \(error)")
        }
        
        Task {
            PersistenceManager.shared.updateTradeExit(
                symbol: contract.symbol,
                exitPrice: activeTrade.entryBar.priceClose,
                buyingPower: account.buyingPower,
                exitSnapshot: strategy.candles.map { Candle(from: $0) }
            )
        }
        print("❌ Exiting trade at \(activeTrade)")
    }
}

// MARK: Helpers

extension Bar: Klines {}

extension TimeInterval {
    func formatCandleTimeInterval() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        switch self {
        case 60...3599:
            formatter.allowedUnits = [.minute]
        case 3600...86399:
            formatter.allowedUnits = [.hour]
        case 86400...604799:
            formatter.allowedUnits = [.day]
        case 604800...:
            formatter.allowedUnits = [.weekOfMonth]
        default:
            formatter.allowedUnits = [.second]
        }
        return formatter.string(from: self) ?? "N/A"
    }
}

// Persistance Candle
extension Candle {
    init (from data: any Klines) {
        self.init(
            timeOpen: data.timeOpen,
            interval: data.interval,
            priceOpen: data.priceOpen,
            priceHigh: data.priceHigh,
            priceLow: data.priceLow,
            priceClose: data.priceClose
        )
    }
}

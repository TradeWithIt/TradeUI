import Foundation
import OrderedCollections
import Brokerage
import TradingStrategy
import TradeWithIt
import SwiftUI

extension Bar: Klines {}

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
    private var tradingHours: [TradingHour] = []
    
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
        Task { self.tradingHours = try await marketData.tradingHour(contract) }
    }
    
    private func setupMarketQuoteData(market: MarketData) async {
        do {
            for await newQuote in try market.quotePublisher(contract: contract).values {
                guard
                    newQuote.contract.symbol == contract.symbol,
                    newQuote.contract.exchangeId == contract.exchangeId,
                    newQuote.contract.currency == contract.currency,
                    newQuote.contract.type == contract.type
                else { continue }
                
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
                        existingQuote.date = Date()  // Update timestamp
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
    
    public func saveCandles(fileProvider: CandleFileProvider) {
        guard !strategy.candles.isEmpty else { return }
        snapshotData(fileProvider: fileProvider, candles: strategy.candles)
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
        guard Date().timeIntervalSince1970 >= (entryBar.timeClose - 5) else { return }
        
        // TODO: Save snapshot
        let units = strategy.unitCount(equity: account.buyingPower)
        guard units > 0 else { return }
        
        guard let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar) else { return }
        
        evaluateMarketCoonditions(trade: Trade(
            entryBar: entryBar,
            price: entryBar.priceClose,
            trailStopPrice: initialStopLoss
        ))
    }
    
    private func evaluateMarketCoonditions(trade: Trade) {
        // TODO: 1. Check for market alerts
        let marketOpen = tradingHours.isMarketOpen()
        guard
            marketOpen.isOpen,
            let timeUntilClose = marketOpen.timeUntilClose,
            timeUntilClose > (interval * 20)
        else { return }
        self.activeTrade = trade
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
        } catch {
            print("Something went wrong while exiting trade: \(error)")
        }
        print("❌ Exiting trade at \(activeTrade)")
    }
}

public extension TimeInterval {
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

import Foundation
import OrderedCollections
import Brokerage
import Persistence
import TradingStrategy
import SwiftUI

public class Watcher: Identifiable {
    public private(set) var contract: any Contract
    public private(set) var interval: TimeInterval
    public private(set) var watcherState: WatcherStateActor
    
    private let userInfo: [String: Any]
    private let strategyType: Strategy.Type
    
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
    private var tradeTask: Task<Void, Never>?
    private var lastScheduledEntryBarTime: TimeInterval?
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
        tradeTask?.cancel()
    }

    public init(
        contract: any Contract,
        interval: TimeInterval,
        strategyType: Strategy.Type,
        marketData: MarketData,
        marketOrder: MarketOrder?,
        fileProvider: CandleFileProvider,
        userInfo: [String: Any] = [:]
    ) throws {
        self.contract = contract
        self.interval = interval
        self.userInfo = userInfo
        self.strategyType = strategyType
        self.marketOrder = marketOrder
        print("Initializing strategy of type:", strategyType)
        self.watcherState = WatcherStateActor(initialStrategy: strategyType.init(candles: []))
        self.quoteTask = Task { await self.setupMarketQuoteData(market: marketData) }
        self.marketDataTask = Task { await self.setupMarketData(marketData: marketData, fileProvider: fileProvider) }
        
        fetchTredingHours(marketData: marketData)
    }
    
    public convenience init(
        contract: any Contract,
        interval: TimeInterval,
        strategyType: Strategy.Type,
        market: Market,
        fileProvider: CandleFileProvider,
        userInfo: [String: Any] = [:]
    ) throws {
        try self.init(
            contract: contract,
            interval: interval,
            strategyType: strategyType,
            marketData: market,
            marketOrder: market,
            fileProvider: fileProvider,
            userInfo: userInfo
        )
    }
    
    public convenience init(
        contract: any Contract,
        interval: TimeInterval,
        strategyType: Strategy.Type,
        fileProvider: CandleFileProvider & MarketData,
        userInfo: [String: Any] = [:]
    ) throws {
        try self.init(
            contract: contract,
            interval: interval,
            strategyType: strategyType,
            marketData: fileProvider,
            marketOrder: nil,
            fileProvider: fileProvider,
            userInfo: userInfo
        )
    }
    
    public func saveCandles(fileProvider: CandleFileProvider) {
        Task {
            let strategy = await watcherState.getStrategy()
            guard !strategy.candles.isEmpty else { return }
            snapshotData(fileProvider: fileProvider, candles: strategy.candles)
        }
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
            var latestQuote: Quote?
            for await newQuote in try market.quotePublisher(contract: contract).values {
                let quote = await watcherState.getQuote()
                if var existingQuote = latestQuote ?? quote {
                    switch newQuote.type {
                    case .bidPrice: existingQuote.bidPrice = newQuote.value
                    case .askPrice: existingQuote.askPrice = newQuote.value
                    case .lastPrice: existingQuote.lastPrice = newQuote.value
                    case .volume: existingQuote.volume = newQuote.value
                    case .none: break
                    }
                    existingQuote.date = Date()
                    latestQuote = existingQuote
                } else {
                    latestQuote = Quote(
                        contract: contract,
                        date: Date(),
                        bidPrice: newQuote.type == .bidPrice ? newQuote.value : nil,
                        askPrice: newQuote.type == .askPrice ? newQuote.value : nil,
                        lastPrice: newQuote.type == .lastPrice ? newQuote.value : nil,
                        volume: newQuote.type == .volume ? newQuote.value : nil
                    )
                }
            }
            if let updatedQuote = latestQuote {
                await watcherState.updateQuote(updatedQuote)
            }
        } catch {
            print("Quote stream error: \(error)")
        }
    }
    
    private func scheduleTradeTask() async {
        tradeTask?.cancel()
        tradeTask = Task {
            do {
                guard !Task.isCancelled else { return }
                try await Task.sleep(for: .seconds(interval - 5.0))
                guard !Task.isCancelled else { return }
                // 5 sec before bar closes
                await enterTradeIfStrategyIsValidated(isSimulation: false)
            } catch {
                guard !Task.isCancelled else { return }
                print("🔴 Failed to schedule trade task: \(error)")
            }
        }
    }
    
    func setupMarketData(marketData: MarketData, fileProvider: CandleFileProvider) async {
        do {
            var updatedUserInfo = userInfo
            updatedUserInfo[MarketDataKey.bufferInfo.rawValue] = interval * Double(maxCandlesCount) * 2.0
            
            for await candlesData in try marketData.marketData(
                contract: contract,
                interval: interval,
                userInfo: updatedUserInfo
            ).values {
                if Task.isCancelled { break }
                let isSimulation = marketData is MarketDataFileProvider
                
                let bars = await updateBars(candlesData.bars, isSimulation: isSimulation)
                let newStrategy = updateStrategy(bars: bars)
                let strategy = await watcherState.getStrategy()
                if strategy.patternIdentified,
                    let timeOpen = strategy.candles.last?.timeOpen,
                    timeOpen != bars.last?.timeOpen {
                    print("✅ pattern was identified")
                    saveCandles(fileProvider: fileProvider)
                }
                
                await watcherState.updateStrategy(newStrategy)
                
                if isSimulation {
                    await enterTradeIfStrategyIsValidated(isSimulation: isSimulation)
                }
                
                await manageActiveTrade(isSimulation: isSimulation)
                if let fileData = marketData as? MarketDataFileProvider,
                   let url = userInfo[MarketDataKey.snapshotFileURL.rawValue] as? URL {
                    fileData.pull(url: url)
                }
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
    
    private func updateBars(_ bars: [Bar], isSimulation: Bool) async -> [Bar] {
        let strategy = await watcherState.getStrategy()
        var currentCandles = OrderedSet(strategy.candles as? [Bar] ?? [])
        if currentCandles.isEmpty {
            currentCandles = OrderedSet(bars)
        } else {
            for bar in bars {
                if let index = currentCandles.lastIndex(of: bar) {
                    currentCandles.update(bar, at: index)
                } else if let lastBar = currentCandles.last, bar.timeOpen >= (lastBar.timeOpen + interval) {
                    if !isSimulation { await scheduleTradeTask() }
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
    
    private func enterTradeIfStrategyIsValidated(isSimulation: Bool) async {
        guard !Task.isCancelled else { return }
        let hasNoActiveTrade = await watcherState.getActiveTrade() == nil
        guard hasNoActiveTrade else { return }
        let strategy = await watcherState.getStrategy()
        guard strategy.patternIdentified, let entryBar = strategy.candles.last else { return }
        
        if isSimulation {
            let units = strategy.unitCount(equity: 1_000_000, feePerUnit: 50)
            let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar) ?? 0
            let trade = Trade(
                entryBar: entryBar,
                price: entryBar.priceClose,
                trailStopPrice: initialStopLoss,
                units: Double(units)
            )
            await watcherState.updateActiveTrade(trade)
            print("✅🟤 enter trade: ", trade)
        } else if let account = marketOrder?.account {
            print("✅ enterTradeIfStrategyIsValidated, symbol: \(symbol): intervl: \(interval)")
            
            saveTradeRecordEntrySnapshot(entryBar: entryBar, buyingPower: account.buyingPower)
            
            let units = strategy.unitCount(equity: account.buyingPower, feePerUnit: 50)
            print("✅ enterTradeIfStrategyIsValidated units: ", units)
            guard units > 0 else { return }
            
            let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar)
            print("✅ enterTradeIfStrategyIsValidated stopLoss: ", initialStopLoss ?? 0)
            guard let initialStopLoss else { return }
            
            await evaluateMarketCoonditions(trade: Trade(
                entryBar: entryBar,
                price: entryBar.priceClose,
                trailStopPrice: initialStopLoss,
                units: Double(units)
            ))
        }
    }
    
    private func saveTradeRecordEntrySnapshot(entryBar: any Klines, buyingPower: Double) {
        print("💿 Saving trade record entry snapshot...")
        Task {
            let strategy = await watcherState.getStrategy()
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
    
    private func evaluateMarketCoonditions(trade: Trade) async {
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
        
        let hasNoActiveTrade = await watcherState.getActiveTrade() == nil
        // Did not enter trade, as there is currently pending trade
        guard hasNoActiveTrade else { return }
        await watcherState.updateActiveTrade(trade)
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
    
    private func manageActiveTrade(isSimulation: Bool) async {
        guard !Task.isCancelled else { return }
        let strategy = await watcherState.getStrategy()
        guard let activeTrade = await watcherState.getActiveTrade(),
                      activeTrade.entryBar.timeOpen != strategy.candles.last?.timeOpen else { return }
        guard strategy.shouldExit(entryBar: activeTrade.entryBar) else { return }
        
        if isSimulation {
            await watcherState.updateActiveTrade(nil)
        } else {
            guard let account = marketOrder?.account else { return }
            guard let position = account.positions.first(where: { $0.label == contract.label }) else { return }
            do {
                try marketOrder?.makeLimitOrder(
                    contract: contract,
                    action: activeTrade.entryBar.isLong ? .sell : .buy,
                    price: position.averageCost,
                    quantity: position.quantity
                )
                await watcherState.updateActiveTrade(nil)
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
        }
        print("❌ Exiting trade at \(activeTrade), lastBar: \(strategy.candles.last)")
    }
    
    // MARK: - Types
    
    public actor WatcherStateActor {
        private var quote: Quote?
        private var strategy: Strategy
        private var activeTrade: Trade?
        
        init(initialStrategy: Strategy) {
            self.strategy = initialStrategy
        }
        
        public func updateQuote(_ newQuote: Quote) {
            self.quote = newQuote
        }
        
        public func getQuote() -> Quote? {
            return quote
        }
        
        public func getStrategy() -> Strategy {
            return strategy
        }
        
        public func updateStrategy(_ newStrategy: Strategy) {
            self.strategy = newStrategy
        }
        
        public func getActiveTrade() -> Trade? {
            return activeTrade
        }
        
        public func updateActiveTrade(_ trade: Trade?) {
            self.activeTrade = trade
        }
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
            priceClose: data.priceClose,
            volume: data.volume
        )
    }
}

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
    public private(set) var activeTrade: Klines? = nil

    private let userInfo: [String: Any]
    private let strategyType: Strategy.Type
    private var counter: Int = 0
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
    
    deinit {
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
    }
    
    private func setupMarketQuoteData(market: MarketData) async {
        do {
            for await quote in try market.quotePublisher(contract: contract).values {
                await MainActor.run { self.quote = quote }
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
                let validStrategy = enterTradeIfStrategyIsValidated(strategy: strat) ?? strat
                
                if validStrategy.patternIdentified {
                    self.counter = 9
                    Task.detached { [weak self] in
                        self?.snapshotData(fileProvider: fileProvider, candles: validStrategy.candles)
                    }
                }
                if self.counter == 1 {
                    Task.detached { [weak self] in
                        self?.snapshotData(fileProvider: fileProvider, candles: validStrategy.candles)
                    }
                }
                if self.counter > 0 { self.counter -= 1 }
                
                manageActiveTrade(strategy: validStrategy)
                
                await MainActor.run { self.strategy = validStrategy }
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
    
    private func enterTradeIfStrategyIsValidated(strategy: (any Strategy)?) -> (any Strategy)? {
        guard let strategy, strategy.patternIdentified, let entryBar = strategy.candles.last else { return strategy }
                
        let units = strategy.evaluateEntry(portfolio: 1000000)
        guard units > 0 else { return strategy }
        
        let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar)
        self.activeTrade = entryBar
        
        return strategy
    }
    
    private func manageActiveTrade(strategy: (any Strategy)) {
        guard let activeTrade else { return }
        guard strategy.shouldExit(entryBar: activeTrade) else { return }
        print("❌ Exiting trade at \(activeTrade.priceClose)")
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

import Foundation
import OrderedCollections
import Brokerage
import TradingStrategy
import TradeWithIt
import Combine
import SwiftUI

extension Bar: Klines {}

private extension TimeInterval {
    var strategyMultiplier: Int {
        self < 900 ? 15 : 4
    }
}

@Observable
public class Watcher: Identifiable {
    public private(set) var symbol: Symbol
    public private(set) var interval: TimeInterval
    public private(set) var strategy: Strategy
    
    private let userInfo: [String: Any]
    private let strategyType: Strategy.Type
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private var cancellable: AnyCancellable?
    private var candles: OrderedSet<Bar> {
        OrderedSet((strategy.candles as? [Bar]) ?? [])
    }
    
    private var maxCandlesCount: Int {
        // Higher 15min frame or 4 bars if trading in over 15min resolution.
        let minimumCandleGroupCount = max(4, Int(900.0 / interval))
        return minimumCandleGroupCount * 60
    }
    
    public var id: String {
        "\(symbol):\(interval)"
    }
    
    deinit {
        cancellable?.cancel()
        cancellable = nil
    }

    public init(
        symbol: Symbol,
        interval: TimeInterval,
        strategyType: Strategy.Type = SupriseBarStrategy.self,
        marketData: MarketData,
        fileProvider: CandleFileProvider,
        userInfo: [String : Any] = [:]
    ) throws {
        self.symbol = symbol
        self.interval = interval
        self.userInfo = userInfo
        self.strategyType = strategyType
        self.strategy = strategyType.init(candles: [], multiplier: interval.strategyMultiplier)
        
        try self.setUpMarketData(marketData, fileProvider: fileProvider)
    }
    
    private func setUpMarketData(_ marketData: MarketData, fileProvider: CandleFileProvider) throws {
        var userInfo = self.userInfo
        userInfo[MarketDataKey.bufferInfo.rawValue] = interval * Double(maxCandlesCount)
        self.cancellable = try marketData.marketData(
            symbol: symbol,
            interval: interval,
            userInfo: userInfo
        )
        .throttle(for: .milliseconds(marketData is MarketDataFileProvider ? 0 : 200), scheduler: queue, latest: false)
        .receive(on: queue)
        .compactMap { [weak self] candles -> [Bar]? in
            self?.updateBars(candles.bars)
        }
        .compactMap { [weak self] bars -> (any Strategy)? in
            self?.updateStrategy(bars: bars)
        }
        .compactMap { [weak self] strategy -> (any Strategy)? in
            self?.enterTradeIfStrategyIsValidated(strategy)
        }
        .map { [weak self] strategy -> (any Strategy) in
            if let self, strategy.patternIdentified {
                DispatchQueue.global().async {
                    self.snapshotData(fileProvider: fileProvider, candles: strategy.candles)
                }
            }
            return strategy
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] strategy in
            self?.strategy = strategy
        }
    }
    
    // MARK: File Provider
    
    private func snapshotData(fileProvider: CandleFileProvider, candles: [any Klines]) {
        guard let bars = candles as? [Bar] else { return }
        do {
            try fileProvider.save(
                symbol: symbol,
                interval: interval,
                bars: bars,
                strategyName: String(describing: strategyType)
            )
        } catch {
            print("🔴 Failed to save snapshot data for:", id)
        }
    }
    
    // MARK: Market Data
    
    private func updateBars(_ bars: [Bar]) -> [Bar] {
        var candles = self.candles
        
        if candles.isEmpty {
            candles = OrderedSet(bars)
        } else {
            for bar in bars {
                if let index = candles.lastIndex(of: bar) {
                    // If the bar exists, update it
                    candles.update(bar, at: index)
                } else if let lastBar = candles.last, bar.timeOpen > lastBar.timeOpen {
                    //If the bar is new append it
                    candles.updateOrAppend(bar)
                }
            }
        }
        
        if candles.count > maxCandlesCount {
            candles.removeFirst(candles.count - maxCandlesCount)
        }
        return Array(candles)
    }
    
    private func updateStrategy(bars: [Bar]) -> any Strategy {
        strategyType.init(
            candles: Array(bars),
            multiplier: interval.strategyMultiplier
        )
    }
    
    private func enterTradeIfStrategyIsValidated(_ strategy: (any Strategy)?) -> (any Strategy)? {
        guard let strategy, strategy.patternIdentified else { return strategy }
        // To do: Enter trade
        return strategy
    }
}

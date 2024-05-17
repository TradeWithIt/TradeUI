import Foundation
import OrderedCollections
import Brokerage
import TradingStrategy
import TradeWithIt
import Combine

#if canImport(SwiftUI)
import SwiftUI
#endif

extension Bar: Klines {}

private extension TimeInterval {
    var strategyMultiplier: Int {
        self < 900 ? 15 : 4
    }
}

#if canImport(SwiftUI)
@Observable
#endif
public class Watcher: Identifiable {
    public private(set) var symbol: Symbol
    public private(set) var interval: TimeInterval
    public private(set) var strategy: Strategy
    
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
        marketData: MarketData
    ) throws {
        self.symbol = symbol
        self.interval = interval
        self.strategyType = strategyType
        self.strategy = strategyType.init(candles: [], multiplier: interval.strategyMultiplier)
        
        try self.setUpMarketData(marketData)
    }
    
    private func setUpMarketData(_ marketData: MarketData) throws {
        self.cancellable = try marketData.marketData(
            symbol: symbol,
            interval: interval,
            buffer: interval * Double(maxCandlesCount)
        )
        .throttle(for: .milliseconds(200), scheduler: queue, latest: false)
        .receive(on: queue)
        .compactMap { [weak self] candles -> [Bar]? in
            return self?.updateBars(candles.bars)
        }
        .compactMap { [weak self] bars -> (any Strategy)? in
            self?.updateStrategy(bars: bars)
        }
        .compactMap { [weak self] strategy -> (any Strategy)? in
            self?.enterTradeIfStrategyIsValidated(strategy)
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] strategy in
            self?.strategy = strategy
        }
    }
    
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

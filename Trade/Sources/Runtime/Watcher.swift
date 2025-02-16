import Foundation
import OrderedCollections
import Brokerage
import TradingStrategy
import TradeWithIt
import Combine
import SwiftUI

extension Bar: Klines {}

@Observable
public class Watcher: Identifiable {
    public private(set) var contract: any Contract
    public private(set) var quote: Quote?
    public private(set) var interval: TimeInterval
    public private(set) var strategy: Strategy
    
    private let userInfo: [String: Any]
    private let strategyType: Strategy.Type
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private var cancellables: Set<AnyCancellable> = []
    private var counter: Int = 0
    private var candles: OrderedSet<Bar> {
        OrderedSet((strategy.candles as? [Bar]) ?? [])
    }
    
    private var maxCandlesCount: Int {
        let targetIntervals: [TimeInterval] = [900.0, 3600.0, 7200.0]
        let multiplier: Int = targetIntervals.first(where: { $0 > interval }).map({ Int($0 / interval) }) ?? 1
        // Higher 15min frame or 4 bars if trading in over 15min resolution.
        return 200 * multiplier
    }
    
    public var symbol: String {
        contract.symbol
    }
    
    public var id: String {
        "\(contract.label):\(interval)"
    }
    
    public var displayName: String {
        "\(symbol): \(interval.formatCandleTimeInterval())"
    }
    
    deinit {
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        cancellables.removeAll()
    }

    public init(
        contract: any Contract,
        interval: TimeInterval,
        strategyType: Strategy.Type = SupriseBarStrategy.self,
        marketData: MarketData,
        fileProvider: CandleFileProvider,
        userInfo: [String : Any] = [:]
    ) throws {
        self.contract = contract
        self.interval = interval
        self.userInfo = userInfo
        self.strategyType = strategyType
        self.strategy = strategyType.init(candles: [])
        
        try self.setUpMarketQuoteData(marketData, fileProvider: fileProvider)
        try self.setUpMarketData(marketData, fileProvider: fileProvider)
    }
    
    private func setUpMarketQuoteData(_ market: MarketData, fileProvider: CandleFileProvider) throws {
        try market.quotePublisher(contract: contract)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] quote in
            self?.quote = quote
        }
        .store(in: &cancellables)
    }
    
    private func setUpMarketData(_ marketData: MarketData, fileProvider: CandleFileProvider) throws {
        var userInfo = self.userInfo
        userInfo[MarketDataKey.bufferInfo.rawValue] = interval * Double(maxCandlesCount) * 2.0
        try marketData.marketData(
            contract: contract,
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
                self.counter = 9
                DispatchQueue.global().async {
                    self.snapshotData(fileProvider: fileProvider, candles: strategy.candles)
                }
            }
            
            if let self, counter == 1 {
                DispatchQueue.global().async {
                    self.snapshotData(fileProvider: fileProvider, candles: strategy.candles)
                }
            }
            
            if let self, counter > 0 {
                counter -= 1
            }
            
            return strategy
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] strategy in
            self?.strategy = strategy
        }
        .store(in: &cancellables)
    }
    
    // MARK: File Provider
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
        strategyType.init(candles: bars)
    }
    
    private func enterTradeIfStrategyIsValidated(_ strategy: (any Strategy)?) -> (any Strategy)? {
        guard let strategy, strategy.patternIdentified else { return strategy }
        // To do: Enter trade
        return strategy
    }
}

public extension TimeInterval {
    func formatCandleTimeInterval() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated

        switch self {
        case 60...3599:  // Seconds to less than an hour
            formatter.allowedUnits = [.minute]
        case 3600...86399:  // One hour to less than a day
            formatter.allowedUnits = [.hour]
        case 86400...604799:  // One day to less than a week
            formatter.allowedUnits = [.day]
        case 604800...:  // One week and more
            formatter.allowedUnits = [.weekOfMonth]
        default:
            formatter.allowedUnits = [.second]  // For less than a minute
        }

        return formatter.string(from: self) ?? "N/A"
    }
}

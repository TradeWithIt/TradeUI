import Foundation
import Runtime
import Brokerage
import Persistence
import NIOConcurrencyHelpers
import Combine
import TradeWithIt
import TradingStrategy

@Observable public class TradeManager {
    private let lock: NIOLock = NIOLock()
    private var cancellable: AnyCancellable?
    
    public let market: Market
    public let persistance: Persistence
    public let fileProvider: MarketDataFileProvider
    public private(set) var watchers: [String: Watcher] = [:]
    var selectedWatcher: String?
    
    private var isLookingUpSuggestions: Bool = false
    
    var watcher: Watcher? {
        guard let id = selectedWatcher else { return nil }
        return lock.withLock {
            return watchers[id]
        }
    }
    
    public func watchersGroups() -> [TradeAggregator: [Watcher]] {
        return lock.withLock {
            // Group watchers by their TradeAggregator
            var groupedWatchers: [TradeAggregator: [Watcher]] = Dictionary(grouping: watchers.values) { $0.tradeAggregator }
            
            // Sort watchers within each group
            for (aggregator, watchers) in groupedWatchers {
                groupedWatchers[aggregator] = watchers.sorted { lhs, rhs in
                    if lhs.contract.type != rhs.contract.type {
                        return lhs.contract.type < rhs.contract.type
                    }
                    if lhs.contract.exchangeId != rhs.contract.exchangeId {
                        return lhs.contract.exchangeId < rhs.contract.exchangeId
                    }
                    if lhs.contract.symbol != rhs.contract.symbol {
                        return lhs.contract.symbol < rhs.contract.symbol
                    }
                    return lhs.interval < rhs.interval
                }
            }
            
            return groupedWatchers
        }
    }
    
    public init(
        market: Market = InteractiveBrokers(),
        persistance: Persistence = PersistenceManager.shared,
        fileProvider: MarketDataFileProvider = MarketDataFileProvider()
    ) {
        self.market = market
        self.persistance = persistance
        self.fileProvider = fileProvider
    }
    
    public func initializeSockets() {
        Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                try market.connect()
            } catch {
                print("initializeSockets failed with error: ", error)
            }
        }
    }
    
    // MARK: - Market Data
    
    public func cancelMarketData(_ asset: Asset) {
        market.unsubscribeMarketData(contract: asset.instrument, interval: asset.interval)
        lock.withLockVoid {
            watchers.removeValue(forKey: asset.id)
        }
    }
    
    @MainActor
    public func marketData<T: Strategy>(contract: any Contract, interval: TimeInterval, strategyType: T.Type) throws {
        guard let strategyName = StrategyRegistry.shared.strategyName(for: strategyType) else {
            print("🔴 Faile to read strategy name from Registry for strategy type:", String(describing: strategyType))
            return
        }
        let assetId = "\(strategyName)\(contract.label):\(interval)"
        try lock.withLockVoid {
            guard watchers[assetId] == nil else { return }
            let agregator = TradeAggregator(contract: contract, marketOrder: market)
            let watcher = try Watcher(
                contract: contract,
                interval: interval,
                strategyType: strategyType,
                strategyName: strategyName,
                tradeAggregator: agregator,
                market: market,
                fileProvider: fileProvider
            )
            watchers[assetId] = watcher
        }
    }
}

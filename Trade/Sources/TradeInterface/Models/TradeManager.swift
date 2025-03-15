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
    
    public func sortedWatchers() -> [Watcher] {
        return lock.withLock {
            watchers.values.sorted { lhs, rhs in
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
        let assetId = "\(contract.label):\(interval)"
        try lock.withLockVoid {
            guard watchers[assetId] == nil else { return }
            let watcher = try Watcher(
                contract: contract,
                interval: interval,
                strategyType: strategyType,
                market: market,
                fileProvider: fileProvider
            )
            watchers[assetId] = watcher
        }
    }
}

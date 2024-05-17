import Foundation
import Runtime
import Brokerage
import NIOConcurrencyHelpers

@Observable public class TradeManager {
    private let lock: NIOLock = NIOLock()
    private let marketData: MarketData
    
    var watchers: [String: Watcher] = [:]
    var selectedWatcher: String?
    
    private var isLookingUpSuggestions: Bool = false
    
    var watcher: Watcher? {
        guard let id = selectedWatcher else { return nil }
        return lock.withLock {
            return watchers[id]
        }
    }
    
    public init(marketData: MarketData = InteractiveBrokers()) {
        self.marketData = marketData
    }
    
    public func initializeSockets() {
        Task {
            try await Task.sleep(for: .milliseconds(200))
            try marketData.connect()
        }
    }
    
    // MARK: - Market Data
    
    public func marketData(_ symbol: String, interval: TimeInterval) throws {
        try lock.withLockVoid {
            let watcher = try Watcher(
                symbol: symbol,
                interval: interval,
                marketData: marketData
            )
            watchers[watcher.id] = watcher
        }
    }
}

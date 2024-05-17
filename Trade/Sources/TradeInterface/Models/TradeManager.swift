import Foundation
import Runtime
import Brokerage
import NIOConcurrencyHelpers

public struct Asset: Codable, Hashable {
    var symbol: String
    var interval: TimeInterval
    
    var id: String {
        "\(symbol):\(interval)"
    }
}

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
    public func search() {
        marketData.search(symbol: "MES")
    }
    
    public func cancelMarketData(_ asset: Asset) {
        marketData.unsubscribeMarketData(symbol: asset.symbol, interval: asset.interval)
        lock.withLockVoid {
            watchers.removeValue(forKey: asset.id)
        }
    }
    
    public func marketData(_ asset: Asset) throws {
        try lock.withLockVoid {
            guard watchers[asset.id] == nil else { return }
            let watcher = try Watcher(
                symbol: asset.symbol,
                interval: asset.interval,
                marketData: marketData
            )
            watchers[asset.id] = watcher
        }
    }
}

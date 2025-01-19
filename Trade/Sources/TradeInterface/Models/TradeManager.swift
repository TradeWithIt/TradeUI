import Foundation
import Runtime
import Brokerage
import NIOConcurrencyHelpers
import Combine

public struct Asset: Codable, Hashable {
    var symbol: String
    var interval: TimeInterval
    
    var id: String {
        "\(symbol):\(interval)"
    }
}

@Observable public class TradeManager {
    private let lock: NIOLock = NIOLock()
    private var cancellable: AnyCancellable?
    
    let market: Market
    let fileProvider: MarketDataFileProvider
    var watchers: [String: Watcher] = [:]
    var selectedWatcher: String?
    
    private var isLookingUpSuggestions: Bool = false
    
    var watcher: Watcher? {
        guard let id = selectedWatcher else { return nil }
        return lock.withLock {
            return watchers[id]
        }
    }
    
    public init(
        market: Market = InteractiveBrokers(),
        fileProvider: MarketDataFileProvider = MarketDataFileProvider()
    ) {
        self.market = market
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
        market.unsubscribeMarketData(symbol: asset.symbol, interval: asset.interval)
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
                marketData: market, 
                fileProvider: fileProvider
            )
            watchers[asset.id] = watcher
        }
    }
    
    public func marketData(contract: any Contract, interval: TimeInterval) throws {
        let assetId = "\(contract.localSymbol):\(interval)"
        try lock.withLockVoid {
            guard watchers[assetId] == nil else { return }
            let watcher = try Watcher(
                symbol: contract.localSymbol,
                interval: interval,
                marketData: market,
                fileProvider: fileProvider
            )
            watchers[assetId] = watcher
        }
    }
}

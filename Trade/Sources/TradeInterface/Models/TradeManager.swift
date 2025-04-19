import Foundation
import Runtime
import Brokerage
import Persistence
import NIOConcurrencyHelpers
import Combine
import TradingStrategy
import OrderedCollections

@Observable public class TradeManager: @unchecked Sendable {
    private let lock: NIOLock = NIOLock()
    private var cancellable: AnyCancellable?
    
    public let market: Market
    public let persistance: Persistence
    public let fileProvider: MarketDataFileProvider
    public private(set) var watchers: [String: Watcher] = [:]
    
    internal var selectedWatcher: String?
    
    private var isLookingUpSuggestions: Bool = false
    private var annoucments: [Annoucment] = []
    
    
    var watcher: Watcher? {
        guard let id = selectedWatcher else { return nil }
        return lock.withLock {
            return watchers[id]
        }
    }
    
    public func removeAllWatchers() {
        lock.withLock {
            watchers.removeAll()
        }
    }
    
    public func watchersGroups() -> OrderedDictionary<TradeAggregator, [Watcher]> {
        return lock.withLock {
            var groupedWatchers: OrderedDictionary<TradeAggregator, [Watcher]> = OrderedDictionary(grouping: watchers.values) { $0.tradeAggregator }
            
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
            
            let sortedGroupedWatchers = OrderedDictionary(
                uniqueKeysWithValues: groupedWatchers.sorted(by: { $0.key.id < $1.key.id })
            )
            return sortedGroupedWatchers
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
    public func marketData<T: Strategy>(
        contract: any Contract,
        interval: TimeInterval,
        strategyName: String,
        strategyType: T.Type
    ) throws {
        let assetId = "\(strategyName)\(contract.label):\(interval)"
        try lock.withLockVoid {
            guard watchers[assetId] == nil else {
                print("🔴 Watcher already exist for strategy: \(strategyName), strategy type:", String(describing: strategyType))
                return
            }
            let agregator = TradeAggregator(
                contract: contract,
                marketOrder: market,
                getNextTradingAlertsAction: { [weak self] in
                    guard let self else { return nil }
                    return nextAnnoucment(in: annoucments)
                },
                tradeEntryNotificationAction: { (trade, recentBar) in
                    TradeAlertHandler.shared.sendAlert(trade, recentBar: recentBar)
                },
                tradeExitNotificationAction: { (trade, recentBar) in
                    TradeAlertHandler.shared.sendAlert(trade, recentBar: recentBar)
                }
            )
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
    
    public func updateAnnoucments(_ annoucments: [Annoucment]) {
        self.annoucments = annoucments
    }
    
    private func nextAnnoucment(after time: TimeInterval = Date().timeIntervalSince1970, in annoucments: [Annoucment]) -> Annoucment? {
        annoucments
            .filter { $0.timestamp > time }
            .sorted { $0.timestamp < $1.timestamp }
            .first
    }

    
    // MARK: Load Dylibs Files and its Strategies
    
    func loadAvailableStrategies(from path: String) -> [String] {
        let handle = dlopen(path, RTLD_NOW)
        guard handle != nil else {
            print("❌ Failed to open \(path)")
            return []
        }

        guard let symbol = dlsym(handle, "getAvailableStrategies") else {
            print("❌ Failed to find `getAvailableStrategies` symbol in \(path)")
            return []
        }

        typealias GetAvailableStrategiesFunc = @convention(c) () -> UnsafePointer<CChar>
        let function = unsafeBitCast(symbol, to: GetAvailableStrategiesFunc.self)

        let strategyPointer = function()
        let strategyList = String(cString: strategyPointer)

        free(UnsafeMutablePointer(mutating: strategyPointer))

        return strategyList.components(separatedBy: ",")
    }

    func loadStrategy(from path: String, strategyName: String) -> Strategy.Type? {
        let handle = dlopen(path, RTLD_NOW)
        guard handle != nil else {
            print("❌ Failed to open \(path): \(String(cString: dlerror()!))")
            return nil
        }

        guard let symbol = dlsym(handle, "createStrategy") else {
            print("❌ Failed to find `createStrategy` symbol in \(path): \(String(cString: dlerror()!))")
            return nil
        }

        typealias CreateStrategyFunc = @convention(c) (UnsafePointer<CChar>) -> UnsafeRawPointer?
        let function = unsafeBitCast(symbol, to: CreateStrategyFunc.self)
        guard let strategyPointer = function(strategyName) else {
            print("❌ `createStrategy()` returned nil")
            return nil
        }

        let factoryBox = Unmanaged<Box<() -> Strategy>>.fromOpaque(strategyPointer).takeRetainedValue()
        let strategyInstance = factoryBox.value()
        let strategyType = type(of: strategyInstance)
        return strategyType
    }

    @MainActor
    public func loadAllUserStrategies(into registry: StrategyRegistry) {
        guard let strategyFolder = UserDefaults.standard.string(forKey: "StrategyFolderPath") else {
            print("⚠️ No strategy folder set in UserDefaults.")
            return
        }

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: strategyFolder) else {
            return
        }

        for file in files where file.hasSuffix(".dylib") {
            let fullPath = (strategyFolder as NSString).appendingPathComponent(file)
            let strategyNames = loadAvailableStrategies(from: fullPath)
            print("🔵 loading: ", strategyNames, fullPath)
            for strategyName in strategyNames {
                if let strategyType = loadStrategy(from: fullPath, strategyName: strategyName) {
                    registry.register(strategyType: strategyType, name: strategyName)
                    print("✅ Successfully registered strategy: \(strategyName)")
                } else {
                    print("❌ Failed to load strategy: \(strategyName)")
                }
            }
        }
        registry.register(strategyType: DoNothingStrategy.self, name: "Viewing only")
        registry.register(strategyType: SupriseBarStrategy.self, name: "Suprise Bar")
    }
    
    // MARK: Types
    
    private final class Box<T> {
        let value: T
        init(_ value: T) { self.value = value }
    }
}

import Foundation
import TradingStrategy
import IBKit
import NIOConcurrencyHelpers

typealias Symbol = String

enum OrderAction: String {
    case buy = "Buy"
    case sell = "Sell"
}

struct Order {
    var quantiy: Int = 1
    let takeProfit: Int
    let stopLoss: Int
}

@Observable public class TradeManager {
    private let lock: NIOLock = NIOLock()
    let ib: InteractiveBrokers
    
    var runtimes: [String: Runtime] = [:]
    var selectedRuntime: String?
    var marketValue: Double = 0
    
    private var isLookingUpSuggestions: Bool = false
    
    var runtime: Runtime? {
        guard let id = selectedRuntime else { return nil }
        return lock.withLock {
            return runtimes[id]
        }
    }
    
    public init() {
        let market = InteractiveBrokers()
        self.ib = market
        market.onBarUpdate = onIBBarUpdate
    }
    
    public func initializeSockets() {
        Task {
            try await Task.sleep(for: .milliseconds(200))
            ib.connect()
        }
    }
    
    // MARK: - Market Data
    
    public func marketData(_ contract: Contract, interval: TimeInterval) throws -> Chart? {
        lock.withLockVoid {
            let runtime = Runtime(
                symbol: contract.symbol,
                interval: interval
            )
            runtimes[runtime.id] = runtime
        }
        return try ib.marketData(contract)
    }
    
    func marketData(
        _ symbol: String,
        interval: TimeInterval,
        secType: String,
        exchange: String
    ) throws -> Chart? {
        lock.withLockVoid {
            let runtime = Runtime(
                symbol: symbol,
                interval: interval
            )
            runtimes[runtime.id] = runtime
        }
        return try ib.marketData(
            symbol,
            secType: .init(rawValue: secType) ?? .future,
            exchange: .init(rawValue: exchange)
        )
    }
    
    func onIBBarUpdate(requestID: Int, data: [IBPriceBar]) {
        guard requestID > 0 else { return }
        let charts: Set<Chart>? = UserDefaults.standard.codable(forKey: "chartSubscriptions")
        guard let savedChart = charts?.first(where: { $0.id == requestID }) else { return }
        
        lock.withLockVoid {
            for key in runtimes.keys where key.starts(with: savedChart.symbol) {
                guard let runtime = runtimes[key] else { continue }
                runtimes[key]?.updateCandles(
                    bars: data.map({ Bar(bar: $0, interval: runtime.interval) }), 
                    ib: ib
                )
            }
        }
    }
}

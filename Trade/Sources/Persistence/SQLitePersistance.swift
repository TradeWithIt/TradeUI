import Foundation

public final class PersistenceManager: Persistence {
    public static let shared = PersistenceManager()

    private init() {}

    private func setupDatabase() throws {}

    public func saveTrade(_ trade: TradeRecord) {}

    public func updateTradeExit(symbol: String, exitPrice: Double, buyingPower: Double, exitSnapshot: [Candle]) {}

    public func fetchAllTrades() -> [TradeRecord] {
        return []
    }
}

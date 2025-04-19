import Foundation

public protocol Persistence: Sendable {
    static var shared: Self { get }
    
    func saveTrade(_ trade: TradeRecord)
    func updateTradeExit(symbol: String, exitPrice: Double, buyingPower: Double, exitSnapshot: [Candle])
    func fetchAllTrades() -> [TradeRecord]
}

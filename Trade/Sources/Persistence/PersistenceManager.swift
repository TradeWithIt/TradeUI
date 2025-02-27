import Foundation

public protocol Persistence {
    static var shared: Self { get }
    
    func saveTrade(_ trade: TradeRecord)
    func updateTradeExit(symbol: String, exitPrice: Double, buyingPower: Double, exitSnapshot: [Candle])
    func fetchAllTrades() -> [TradeRecord]
}

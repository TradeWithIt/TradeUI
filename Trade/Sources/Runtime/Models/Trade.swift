import Foundation
import TradingStrategy

public struct Trade: Sendable {
    public var entryBar: Klines
    public var price: Double
    public var trailStopPrice: Double
    public var units: Double
    
    public init(entryBar: Klines, price: Double, trailStopPrice: Double, units: Double) {
        self.entryBar = entryBar
        self.price = price
        self.trailStopPrice = trailStopPrice
        self.units = units
    }
}

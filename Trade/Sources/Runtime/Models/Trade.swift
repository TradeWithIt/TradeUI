import Foundation
import TradingStrategy

public struct Trade {
    public var entryBar: Klines
    public var price: Double
    public var trailStopPrice: Double
    
    public init(entryBar: Klines, price: Double, trailStopPrice: Double) {
        self.entryBar = entryBar
        self.price = price
        self.trailStopPrice = trailStopPrice
    }
}

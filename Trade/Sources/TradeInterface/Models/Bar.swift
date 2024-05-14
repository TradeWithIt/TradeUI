import Foundation
import TradingStrategy

struct Bar: Klines {
    var timeOpen: TimeInterval
    var interval: TimeInterval

    var priceOpen: Double
    var priceHigh: Double
    var priceLow: Double
    var priceClose: Double
    
    init(
        timeOpen: TimeInterval,
        interval: TimeInterval,
        priceOpen: Double,
        priceHigh: Double,
        priceLow: Double,
        priceClose: Double
    ) {
        self.timeOpen = timeOpen
        self.interval = interval
        self.priceOpen = priceOpen
        self.priceHigh = priceHigh
        self.priceLow = priceLow
        self.priceClose = priceClose
    }
}

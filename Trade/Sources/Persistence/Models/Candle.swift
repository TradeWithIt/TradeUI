import Foundation

public struct Candle: Codable, Hashable {
    public var timeOpen: TimeInterval
    public var interval: TimeInterval

    public var priceOpen: Double
    public var priceHigh: Double
    public var priceLow: Double
    public var priceClose: Double
    
    public init(
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


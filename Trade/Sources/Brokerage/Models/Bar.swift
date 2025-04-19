import Foundation

public struct CandleData: Sendable {
    public var symbol: Symbol
    public var interval: TimeInterval
    public var bars: [Bar]
    
    public init(symbol: Symbol, interval: TimeInterval, bars: [Bar]) {
        self.symbol = symbol
        self.interval = interval
        self.bars = bars
    }
}

public struct Bar: Sendable, Codable, Hashable {
    public var timeOpen: TimeInterval
    public var interval: TimeInterval

    public var priceOpen: Double
    public var priceHigh: Double
    public var priceLow: Double
    public var priceClose: Double
    public var volume: Double?
    
    public init(
        timeOpen: TimeInterval,
        interval: TimeInterval,
        priceOpen: Double,
        priceHigh: Double,
        priceLow: Double,
        priceClose: Double,
        volume: Double?
    ) {
        self.timeOpen = timeOpen
        self.interval = interval
        self.priceOpen = priceOpen
        self.priceHigh = priceHigh
        self.priceLow = priceLow
        self.priceClose = priceClose
        self.volume = volume
    }
}

extension Bar {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(timeOpen)
    }

    public static func == (lhs: Bar, rhs: Bar) -> Bool {
        return lhs.timeOpen == rhs.timeOpen
    }
}

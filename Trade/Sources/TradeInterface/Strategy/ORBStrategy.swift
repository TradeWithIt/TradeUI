import Foundation
import TradingStrategy

public struct ORBStrategy: Strategy {
    public let candles: [Klines]
    public let levels: SupportResistance
    public let phases: [Phase]
    public let supportBars: [Klines] = []
    public let supportPhases: [Phase] = []
    public let longTermMA: [Double] = []
    public let shortTermMA: [Double]
    public var scale: Scale
    public var supportScale: Scale
    
    public init(candles: [Klines]) {
        let interval = candles.first?.interval ?? 60
        // Calculate number of candles for the whole trading day (8 hours of market time)
        let totalTradingSeconds = 8 * 3600.0
        let candleCount = Int(totalTradingSeconds / interval)
        let scale = Scale(data: candles, candlesPerScreen: candleCount)
        
        self.candles = candles
        self.scale = scale
        self.supportScale = scale
        self.shortTermMA = candles.exponentialMovingAverage(period: 34)
        // Compute ORB Levels
        self.levels = computeORBLevels(candles: candles)
        
        // Select ORB period
        self.phases = computeORBPhase(candles: candles)
    }
    
    public var patternInformation: [String: Bool] {
        [
            "Above ORB High": isAboveORBHigh,
            "Below ORB Low": isBelowORBLow,
            "Within ORB Range": isWithinORB,
        ]
    }
    
    public var patternIdentified: Bool {
        isAboveORBHigh || isBelowORBLow
    }
    
    private var isAboveORBHigh: Bool {
        guard let lastCandle = candles.last, let orh = levels.resistance.sorted(by: { $0.level > $1.level }).first?.level else { return false }
        return lastCandle.priceClose > orh
    }
    
    private var isBelowORBLow: Bool {
        guard let lastCandle = candles.last, let orl = levels.resistance.sorted(by: { $0.level < $1.level }).first?.level else { return false }
        return lastCandle.priceClose < orl
    }
    
    private var isWithinORB: Bool {
        !isAboveORBHigh && !isBelowORBLow
    }
    
    public func unitCount(equity: Double, feePerUnit cost: Double) -> Int {
        let riskPerTrade = equity * 0.01  // Risking 1% per trade
        let tradeCost = cost * 2  // Considering buy & sell cost
        return max(Int(riskPerTrade / tradeCost), 0)
    }
    
    public func adjustStopLoss(entryBar: Klines) -> Double? {
        let atr = (entryBar.priceHigh - entryBar.priceLow) * 1.5
        return entryBar.priceClose - atr
    }
    
    public func shouldExit(entryBar: Klines) -> Bool {
        guard let lastCandle = candles.last else { return false }
        return lastCandle.priceClose < entryBar.priceClose * 0.98  // Exit if price drops 2%
    }
}

// MARK: ORB phases
/// ORB phases, support (red) for day ago, resistance (green) for recent day
private func computeORBPhase(candles: [Klines]) -> [Phase] {
    guard let lastBar = candles.last else { return [] }
    var nyCalendar = Calendar(identifier: .gregorian)
    nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!
    
    let dayForLastBar = nyCalendar.startOfDay(for: Date(timeIntervalSince1970: lastBar.timeOpen))
    let marketOpenTime = dayForLastBar.timeIntervalSince1970 + (9.5 * 3600)
    
    let morningCandles = candles.enumerated().filter { $0.element.timeOpen >= marketOpenTime && $0.element.timeOpen < (marketOpenTime + 3600) }
    let start = morningCandles.first?.offset ?? 0
    let end = morningCandles.last?.offset ?? 0
    return [Phase(type: .sideways, range: start...end)]
}

// MARK: ORB levels
/// ORB levels, support (red) for day ago, resistance (green) for recent day

private func computeORBLevels(candles: [Klines], time: Range<TimeInterval>) -> [Level] {
    let marketOpenTime = time.lowerBound
    let marketCloseTime = time.upperBound
    let morningCandles = candles.enumerated().filter { $0.element.timeOpen >= marketOpenTime && $0.element.timeOpen < marketCloseTime }
    guard let highest = morningCandles.max(by: { $0.element.priceHigh < $1.element.priceHigh }),
          let lowest = morningCandles.min(by: { $0.element.priceLow < $1.element.priceLow }) else {
        return []
    }
    
    let high = highest.element.priceHigh
    let low = lowest.element.priceLow
    let mid = (high + low) / 2
    
    return [
        Level(
            index: highest.offset,
            time: highest.element.timeOpen,
            touches: [Touch(index: highest.offset, time: highest.element.timeOpen, closePrice: high)]
        ),
        Level(
            index: highest.offset,
            time: highest.element.timeOpen,
            touches: [Touch(index: highest.offset, time: highest.element.timeOpen, closePrice: mid)]
        ),
        Level(
            index: lowest.offset,
            time: lowest.element.timeOpen,
            touches: [Touch(index: lowest.offset, time: lowest.element.timeOpen, closePrice: low)]
        ),
    ]
}

private func computeORBLevels(candles: [Klines]) -> SupportResistance {
    guard let lastBar = candles.last else {
        return SupportResistance(support: [], resistance: [])
    }
    var nyCalendar = Calendar(identifier: .gregorian)
    nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!
    
    let dayForLastBar = nyCalendar.startOfDay(for: Date(timeIntervalSince1970: lastBar.timeOpen))
    let yesterdayOfLastBar = nyCalendar.date(byAdding: .day, value: -1, to: dayForLastBar) ?? dayForLastBar
    let marketOpenTime = dayForLastBar.timeIntervalSince1970 + (9.5 * 3600)
    let yesterdayOpenTime = yesterdayOfLastBar.timeIntervalSince1970 + (9.5 * 3600)
        
    let yesterdayLevels = computeORBLevels(candles: candles, time: yesterdayOpenTime..<(yesterdayOpenTime + 3600))
    let todayLevels = computeORBLevels(candles: candles, time: marketOpenTime..<(marketOpenTime + 3600))
    return SupportResistance(
        support: yesterdayLevels,
        resistance: todayLevels
    )
}

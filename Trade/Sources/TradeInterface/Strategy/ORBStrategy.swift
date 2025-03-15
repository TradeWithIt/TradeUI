import Foundation
import TradingStrategy

public struct ORBStrategy: Strategy {
    public let charts: [[Klines]]
    public let levels: [Level]
    public let distribution: [[Phase]]
    public let indicators: [[String: [Double]]]
    public let resolution: [Scale]
    
    public init(candles: [Klines]) {
        let interval = candles.first?.interval ?? 60
        let totalTradingSeconds = 8 * 3600.0
        let candleCount = Int(totalTradingSeconds / interval)
        let scale = Scale(data: candles, candlesPerScreen: candleCount)
        self.charts = [candles]
        self.resolution = [scale]
        
        self.indicators = [[
            "34 EMA": candles.exponentialMovingAverage(period: 34),
            "VWAP": candles.computeVWAP()
        ]]
        
        let orb = computeORB(candles: candles)
        self.levels = orb.levels
        self.distribution = [orb.phases]
    }

    public var patternIdentified: Bool {
        return isAboveORBHigh || isBelowORBLow
    }
    
    public var patternInformation: [String: Bool] {
        return [
            "Above ORB High": isAboveORBHigh,
            "Below ORB Low": isBelowORBLow,
        ]
    }

    private var isAboveORBHigh: Bool {
        guard let lastCandle = charts.first?.last else { return false }
        let highestLevel = levels.max(by: { $0.level < $1.level })?.level
        return highestLevel.map { lastCandle.priceClose > $0 } ?? false
    }
    
    private var isBelowORBLow: Bool {
        guard let lastCandle = charts.first?.last else { return false }
        let lowestLevel = levels.min(by: { $0.level < $1.level })?.level
        return lowestLevel.map { lastCandle.priceClose < $0 } ?? false
    }
    
    // MARK: - Position Manager & Trade Decision
    
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
        guard let lastCandle = charts.first?.last else { return false }
        return lastCandle.priceClose < entryBar.priceClose * 0.98  // Exit if price drops 2%
    }
}

private func computeORBLevels(candles: [Klines], time: Range<TimeInterval>) -> (levels: [Level], phases: [Phase]) {
    let openTime = time.lowerBound
    let closeTime = time.upperBound
    guard let lastTime = candles.last?.timeOpen, lastTime >= openTime else { return ([], []) }
    
    var highest: EnumeratedSequence<[Klines]>.Element?
    var lowest: EnumeratedSequence<[Klines]>.Element?
    var start: Int?
    var end: Int?
    
    for candle in candles.enumerated().reversed() {
        if candle.element.timeOpen < openTime { break }  // Stop if we go past the time range
        if candle.element.timeOpen >= closeTime { continue } // Skip candles after the range
        
        if highest == nil || candle.element.priceHigh > highest!.element.priceHigh {
            highest = candle
        }
        if lowest == nil || candle.element.priceLow < lowest!.element.priceLow {
            lowest = candle
        }
        
        if end == nil { end = candle.offset }
        start = candle.offset
    }
    
    guard let highest, let lowest, let phaseStart = start, let phaseEnd = end else {
        return ([], [])
    }
    
    let high = highest.element.priceHigh
    let low = lowest.element.priceLow
    let mid = (high + low) / 2
    
    let levels = [
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
    
    let phase = [Phase(type: .sideways, range: phaseStart...phaseEnd)]
    
    return (levels, phase)
}

private func computeORB(candles: [Klines]) -> (levels: [Level], phases: [Phase]) {
    guard let lastBar = candles.last else { return ([], []) }

    var nyCalendar = Calendar(identifier: .gregorian)
    nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!

    let dayForLastBar = nyCalendar.startOfDay(for: Date(timeIntervalSince1970: lastBar.timeOpen))
    let yesterdayOfLastBar = nyCalendar.date(byAdding: .day, value: -1, to: dayForLastBar) ?? dayForLastBar

    let marketOpenTime = dayForLastBar.timeIntervalSince1970 + (9.5 * 3600) // 9:30 AM EST
    let yesterdayOpenTime = yesterdayOfLastBar.timeIntervalSince1970 + (9.5 * 3600) // 9:30 AM EST
    let afternoonORBStart = dayForLastBar.timeIntervalSince1970 + (14.5 * 3600)  // 2:30 PM EST

    // **Prioritize 30-Minute ORB**
    let thirtyMinuteORB = computeORBLevels(candles: candles, time: marketOpenTime..<(marketOpenTime + 1800))
    guard thirtyMinuteORB.levels.isEmpty else { return thirtyMinuteORB }

    // **If 30-Minute ORB is not found, check 60-Minute ORB**
    let sixtyMinuteORB = computeORBLevels(candles: candles, time: marketOpenTime..<(marketOpenTime + 3600))
    guard sixtyMinuteORB.levels.isEmpty else { return sixtyMinuteORB }

    // **If neither exists, check Afternoon ORB**
    let afternoonORB = computeORBLevels(candles: candles, time: afternoonORBStart..<(afternoonORBStart + 1800))
    guard afternoonORB.levels.isEmpty else { return afternoonORB }

    // **Ensure previous day's ORB persists until 9:30 AM next day**
    let yesterdayThirtyMinuteORB = computeORBLevels(candles: candles, time: yesterdayOpenTime..<(yesterdayOpenTime + 1800))
    guard yesterdayThirtyMinuteORB.levels.isEmpty else { return yesterdayThirtyMinuteORB }

    let yesterdaySixtyMinuteORB = computeORBLevels(candles: candles, time: yesterdayOpenTime..<(yesterdayOpenTime + 3600))
    return yesterdaySixtyMinuteORB
}

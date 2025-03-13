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
        
        let shortTermMA = candles.exponentialMovingAverage(period: 34)
        let vwap = computeVWAP(candles: candles)
        
        self.indicators = [[
            "34 EMA": shortTermMA,
            "VWAP": vwap
        ]]
        
        self.levels = computeORBLevels(candles: candles)
        self.distribution = [computeORBPhase(candles: candles)]
    }

    public var patternIdentified: Bool {
        return isAboveORBHigh || isBelowORBLow
    }
    
    public var patternInformation: [String: Bool] {
        return [
            "Above ORB High": isAboveORBHigh,
            "Below ORB Low": isBelowORBLow,
            "Within ORB Range": !(isAboveORBHigh || isBelowORBLow)
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

// MARK: Compute VWAP
private func computeVWAP(candles: [Klines]) -> [Double] {
    var cumulativeVWAP: [Double] = []
    var cumulativeVolume: Double = 0
    var cumulativePriceVolume: Double = 0
    
    for candle in candles {
        guard let volume = candle.volume else { continue }
        cumulativeVolume += volume
        cumulativePriceVolume += ((candle.priceHigh + candle.priceLow + candle.priceClose) / 3) * volume
        cumulativeVWAP.append(cumulativePriceVolume / cumulativeVolume)
    }
    return cumulativeVWAP
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
    let openTime = time.lowerBound
    let closeTime = time.upperBound
    guard let lastTime = candles.last?.timeOpen, lastTime >= openTime else { return [] }
    let morningCandles = candles.enumerated().filter { $0.element.timeOpen >= openTime && $0.element.timeOpen < closeTime }
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

private func computeORBLevels(candles: [Klines]) -> [Level] {
    guard let lastBar = candles.last else {
        return []
    }
    var nyCalendar = Calendar(identifier: .gregorian)
    nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!
    
    let dayForLastBar = nyCalendar.startOfDay(for: Date(timeIntervalSince1970: lastBar.timeOpen))
    let yesterdayOfLastBar = nyCalendar.date(byAdding: .day, value: -1, to: dayForLastBar) ?? dayForLastBar
    let marketOpenTime = dayForLastBar.timeIntervalSince1970 + (9.5 * 3600)
    let yesterdayOpenTime = yesterdayOfLastBar.timeIntervalSince1970 + (9.5 * 3600)
        
    let todayLevels = computeORBLevels(candles: candles, time: marketOpenTime..<(marketOpenTime + 3600))
    guard todayLevels.isEmpty else {
        return todayLevels
    }
    let yesterdayLevels = computeORBLevels(candles: candles, time: yesterdayOpenTime..<(yesterdayOpenTime + 3600))
    return yesterdayLevels
}

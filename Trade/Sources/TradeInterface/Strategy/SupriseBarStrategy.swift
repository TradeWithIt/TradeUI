import Foundation
import TradingStrategy

public struct SupriseBarStrategy: Strategy {
    public var id = "com.suprise.bar"
    public var name = "Suprise Bar"
    public var version: (major: Int, minor: Int, patch: Int) = (1, 0, 0)
    public let charts: [[Klines]]
    public let levels: [Level]
    public let distribution: [[Phase]]
    public let indicators: [[String: [Double]]]
    public let resolution: [Scale]
    
    public init(candles: [Klines]) {
        let copiedCandles = Array(candles)
        let interval = copiedCandles.first?.interval ?? 60
        let shortTermMA: [Double] = copiedCandles.exponentialMovingAverage(period: Constants.shortTerm)
        let scale = Scale(data: copiedCandles)
        let phases = copiedCandles
            .detectSidewaysVisualRange(scale: scale, canvasSize: Constants.canvasSize)
        
        let targetIntervals: [TimeInterval] = [900.0, 3600.0, 7200.0]
        let targetInterval: TimeInterval = targetIntervals.first(where: { $0 > interval }) ?? 900
        let bars = copiedCandles.aggregateBars(to: targetInterval)
        let supportScale = Scale(data: bars)
        let longTermMA: [Double] = bars.triangularMovingAverage(period: Constants.longTerm)
        let supportPhases = bars.convertToPhases(minPhaseLength: 8, longTermMA: longTermMA)
        
        let levels = bars
            .generateSRLevels(scale: supportScale, chartSize: Constants.canvasSize)
 
        self.charts = [copiedCandles, bars]
        self.resolution = [scale, supportScale]
        self.indicators = [
            // Left chart
            [Constants.shortTermName: shortTermMA],
            // Support Chart
            [Constants.longTermName: longTermMA],
        ]
        
        self.levels = levels
        self.distribution = [phases, supportPhases]
    }
    
    // MARK: - Computed properties
    
    var scale: Scale {
        resolution.first ?? Scale(data: [])
    }
    
    var phases: [Phase] {
        distribution.first ?? []
    }
    
    var supportPhases: [Phase] {
        distribution.last ?? []
    }
    
    var shortTermMA: [Double] {
        indicators.first?[Constants.shortTermName] ?? []
    }
    
    var longTermMA: [Double] {
        indicators.last?[Constants.longTermName] ?? []
    }
    
    // MARK: - Actual Logic
    
    public var patternInformation: [String: Bool] {
        [
            "Trend": isTrendAligned,
            "Sideways": isSignificantSidewaysPresent,
            "Small bars": isSmallBars,
            "Breakout": isBreakingThrough,
            "Surprise": isSurprise,
            "Space": isSeparatedFromMA,
        ]
    }
    
    public var patternIdentified: Bool {
        let result = isTrendAligned
        && isSignificantSidewaysPresent
        && isSmallBars
        && isSeparatedFromMA
        && isSurprise
        if result {
            let _ = isSignificantSidewaysPresent
            let _ = isTrendAligned
            let _ = isSignificantSidewaysPresent
            let _ = isSmallBars
            let _ = isSeparatedFromMA
            let _ = isSurprise
        }
        return result
    }
    
    public var isLong: Bool {
        guard let bar = candles.last else { return true }
        return bar.isLong
    }
    
    // Body wicks in opposite one fifths
    // is breaking thru resistance/support
    // bar is larger or equal than amplitiude in 2x bar width
    public var isSurprise: Bool {
        guard let bar = candles.last else { return false }
        
        let height = scale.height(bar.body, size: Constants.canvasSize)
        let length = (2 * height)
        let barCount = scale.barCount(forLength: length, size: Constants.canvasSize)
        
        let start = (candles.count - 1 - barCount)
        guard height > 0, barCount > 0, start >= 0, start < (candles.count - 1) else { return false }
        
        let slice = candles[start ..< (candles.count - 1)].map { $0 }
        let max = slice.map { $0.priceHigh }.max() ?? bar.priceClose
        let min = slice.map { $0.priceLow }.min() ?? bar.priceClose
        let isValid = (bar.priceHigh - bar.priceLow) >= (max - min)
        return isValid && oppositeOneFifths && isBreakingThrough
    }
    
    private var isSeparatedFromMA: Bool {
        guard let lastCandle = candles.last, let lastMA = shortTermMA.last else {
            return false
        }
        
        let yRange = scale.y.upperBound - scale.y.lowerBound
        let dynamicThreshold = yRange * 0.05
        return abs(lastCandle.priceClose - lastMA) >= dynamicThreshold
    }
    
    // 1st Bar in Opposite 1/5ths
    // Instead of opossite fiths, we check the over all size to be less than the bar
    public var oppositeOneFifths: Bool {
        guard let bar = candles.last else { return false }
        // let oneFifths = (bar.body * 0.2)
        let sizeRequirement = (bar.body * 0.5)
        guard sizeRequirement > 0 else { return false }
        return bar.lowerWick <= sizeRequirement &&  bar.upperWick <= sizeRequirement
    }
    
    // Bar breaking through a significant high or low - Yes or No
    // with 50% breaking through a sideways high or low - Yes or No
    public var isBreakingThrough: Bool {
        guard let bar = candles.last else { return false }
        let halfBody = bar.body * 0.5
        
        guard halfBody > 0 else { return false }
        
        // Bar breaking through a significant high or low - Yes or No
        var didBreak = false
        if bar.isLong {
            if let midSupport = levels.min(by: { abs($0.level - bar.priceLow) < abs($1.level - bar.priceHigh) }) {
                didBreak = midSupport.level < bar.priceClose
            }
        } else  {
            if let midSupport = levels.min(by: { abs($0.level - bar.priceHigh) < abs($1.level - bar.priceLow) }) {
                didBreak = midSupport.level > bar.priceClose
            }
        }
        
        // with 50% breaking through a sideways high or low - Yes or No
        guard let timePhase = phases.timePhaseIfLast, timePhase.range.count > 3 else { return false }
        
        guard let min = candles[timePhase.range].min(by: { (a, b) -> Bool in
            return a.priceLow < b.priceLow
        })?.priceLow,
        let max = candles[timePhase.range].max(by: { (a, b) -> Bool in
            return a.priceHigh < b.priceHigh
        })?.priceHigh else { return false }
        
        if bar.isLong {
            didBreak = didBreak && (max < bar.priceClose)
        } else  {
            didBreak = didBreak && (min > bar.priceClose)
        }
        
        return didBreak
    }
    
    public var isSmallBars: Bool {
        guard let bar = candles.last, candles.count > 3 else { return false }
        
        let height = scale.height(bar.body, size: Constants.canvasSize)
        let length = (2 * height)
        let barCount = scale.barCount(forLength: length, size: Constants.canvasSize)
        
        // Bars in the time phase from OPEN to CLOSE MUST Be Less Than 50% of the Entry Bar from OPEN to CLOSE
        let halfBody = bar.body * 0.5
        guard halfBody > 0 else { return false }
        guard barCount > 3 else { return false }
        for i in max(0, (candles.count - barCount)) ..< (candles.count - 3) {
            guard candles[i].body <= halfBody else {
                return false
            }
        }
        
        // The 2 bars before the entry bar from OPEN to CLOSE MUST Be Less Than 25% of the Entry Bar from OPEN to
        let thirdBody = bar.body * 0.3
        let quaterBody = bar.body * 0.25
        var total = 0.0
        for i in (candles.count - 3) ..< (candles.count - 1) {
            guard candles[i].body <= thirdBody else {
                return false
            }
            total += candles[i].body
        }
        guard (total / 2.0) <= quaterBody else { return false }
        return true
    }
    
    // 2 x Length of the Entry Bar
    public var isSignificantSidewaysPresent: Bool {
        guard let bar = candles.last, candles.count > 3 else { return false }
        
        let height = scale.height(bar.body, size: Constants.canvasSize)
        let length = (2 * height)
        let barCount = scale.barCount(forLength: length, size: Constants.canvasSize)
        
        guard height > 0, barCount > 0 else { return false }
        guard let timePhase = phases.timePhaseIfLast, timePhase.range.count > 3 else { return false }
        return timePhase.range.length >= barCount
    }
    
    /// Determines if we are **aligned with the trend**
    public var isTrendAligned: Bool {
        guard let pricePhase = supportPhases.lastPricePhase else { return false }
        if isLong {
            return pricePhase.type == .uptrend
        } else {
            return pricePhase.type == .downtrend
        }
    }
    
    public func shouldEnterWitUnitCount(
        entryBar: Klines,
        equity: Double,
        feePerUnit cost: Double,
        nextAnnoucment annoucment: Annoucment?
    ) -> Int {
        // If entry bar is the annoucment bar, we do not enter.
        if let annoucment,
           annoucment.timestamp > entryBar.timeOpen,
           annoucment.timestamp < (entryBar.timeOpen + entryBar.interval) {
            return 0
        }
        
        let closeTime = Date(timeIntervalSince1970: entryBar.timeClose)
        let now = Date()
        let timeRemaining = closeTime.timeIntervalSince(now)
        
        guard timeRemaining <= 5.0 && timeRemaining > 0 else {
            return 0
        }
        
        let entry = entryBar.priceClose
        let stop: Double
        if entryBar.isLong {
            stop = entryBar.priceLow + (entryBar.body * 0.25)
        } else {
            stop = entryBar.priceHigh - (entryBar.body * 0.25)
        }
        let riskTolerance: Double = 0.025
        guard entry > 0, stop > 0 else { return 0 }
        let points = abs(entry - stop)
        guard points > 0 else { return 0 }
        
        let maxLoss = equity * riskTolerance
        let rawSize = Int(maxLoss / points)
        
        // Ensure position size is large enough to cover fees
        let minSizeForFees = Int(ceil(cost / points))
        return max(rawSize, minSizeForFees)
    }
    
    public func adjustStopLoss(entryBar: Klines) -> Double? {
        // Trailing Stop Loss at 25% from the bottom (for longs) or 25% from top (for shorts)
        let stopLossLevel: Double
        if entryBar.isLong {
            stopLossLevel = entryBar.priceLow + (entryBar.body * 0.25)
        } else {
            stopLossLevel = entryBar.priceHigh - (entryBar.body * 0.25)
        }
        
        return stopLossLevel
    }
    
    public func shouldExit(entryBar: Klines, nextAnnoucment annoucment: Annoucment?) -> Bool {
        guard
            let latestBar = candles.last,
            let momentumTermMA = shortTermMA.last
        else { return false }
        
        // If next bar has annoucment, we exit
        if let annoucment, annoucment.annoucmentImpact == .high,
           annoucment.timestamp > latestBar.timeOpen,
           annoucment.timestamp < (latestBar.timeOpen + latestBar.interval * 2) {
            return true
        }
        
        return entryBar.isLong ? latestBar.priceClose < momentumTermMA : latestBar.priceClose > momentumTermMA
    }
    
    // MARK: Constants
    
    public enum Constants {
        //(420.0, 362.29541015625)
        public static let canvasSize = CGSize(width: 420, height: 360)
        public static let longTerm = 24
        public static let shortTerm = 8
        
        public static let longTermName = "24 TMA"
        public static let shortTermName = "8 TMA"
    }
}

public extension [Klines] {
    func detectSidewaysVisualRange(
        scale: Scale,
        canvasSize: CGSize
    ) -> [Phase] {
        guard
            count >= 2,
            let lastCandle = self.last
        else { return [] }
        
        let candlesToProcess = self.dropLast()
        let height = scale.height(lastCandle.body, size: canvasSize)
        let length = (2 * height)
        let barCount = scale.barCount(forLength: length, size: canvasSize)

        let endIndex = candlesToProcess.count - 1
        let startIndex = endIndex - barCount
        
        guard startIndex >= 0 else { return [] }
        let maxPrice = candlesToProcess[startIndex...endIndex].max(by: { $0.priceHigh < $1.priceHigh })?.priceHigh ?? lastCandle.priceHigh
        let minPrice = candlesToProcess[startIndex...endIndex].min(by: { $0.priceHigh < $1.priceHigh })?.priceLow ?? lastCandle.priceLow

        let rectHeight = scale.height(maxPrice - minPrice, size: canvasSize)
        guard
            rectHeight > 0,
            (rectHeight * 2.7) <= length,
            rectHeight <= height,
            startIndex <= endIndex
        else { return [] }
        
        return [Phase(type: .sideways, range: startIndex...endIndex)]
    }
}


import Foundation
import TradingStrategy

public struct ORBStrategy: Strategy {
    public let candles: [Klines]
    public let levels: SupportResistance
    public let phases: [Phase] = []
    public let supportBars: [Klines] = []
    public let supportPhases: [Phase] = []
    public let longTermMA: [Double] = []
    public let shortTermMA: [Double] = []
    public var scale: Scale
    public var supportScale: Scale
    
    public init(candles: [Klines]) {
        let interval = candles.first?.interval ?? 60
        var scale = Scale(data: candles)
        // Calculate number of candles for the whole trading day (6.5 hours of market time)
        let totalTradingSeconds = 6.5 * 3600
        let candleCount = Int(totalTradingSeconds / interval)
        scale.x = 0..<candleCount
        
        self.candles = candles
        self.scale = scale
        self.supportScale = scale
        
        // Compute ORB Levels
        self.levels = ORBStrategy.computeORBLevels(candles: candles)
    }
    
    public var patternInformation: [String: Bool] {
        [
            "ORB Breakout": isBreakout,
            "Above ORB High": isAboveORBHigh,
            "Below ORB Low": isBelowORBLow,
            "Within ORB Range": isWithinORB,
        ]
    }
    
    public var patternIdentified: Bool {
        isBreakout || isAboveORBHigh || isBelowORBLow
    }
    
    private var isBreakout: Bool {
        guard let lastCandle = candles.last else { return false }
        return lastCandle.priceClose > levels.resistance.last?.level ?? 0 ||
               lastCandle.priceClose < levels.support.last?.level ?? 0
    }
    
    private var isAboveORBHigh: Bool {
        guard let lastCandle = candles.last, let orh = levels.resistance.last?.level else { return false }
        return lastCandle.priceClose > orh
    }
    
    private var isBelowORBLow: Bool {
        guard let lastCandle = candles.last, let orl = levels.support.last?.level else { return false }
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
    
    private static func computeORBLevels(candles: [Klines]) -> SupportResistance {
        var nyCalendar = Calendar(identifier: .gregorian)
        nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        
        let marketOpenTime = nyCalendar.startOfDay(for: Date()).timeIntervalSince1970 + (9.5 * 3600)
        let marketCloseTime = marketOpenTime + 3600
        
        let morningCandles = candles.filter { $0.timeOpen >= marketOpenTime && $0.timeOpen < marketCloseTime }
        guard let high = morningCandles.max(by: { $0.priceHigh < $1.priceHigh })?.priceHigh,
              let low = morningCandles.min(by: { $0.priceLow < $1.priceLow })?.priceLow else {
            return SupportResistance(support: [], resistance: [])
        }
        let mid = (high + low) / 2
        return SupportResistance(
            support: [
                Level(
                    index: 0,
                    time: morningCandles.first?.timeOpen ?? 0,
                    touches: [
                        Touch(index: 0, time: morningCandles.first?.timeOpen ?? 0, closePrice: low)
                    ]
                )
            ],
            
            resistance: [
                Level(
                    index: 0,
                    time: morningCandles.first?.timeOpen ?? 0,
                    touches: [
                        Touch(index: 0, time: morningCandles.first?.timeOpen ?? 0, closePrice: high)
                    ]
                ),
                Level(
                    index: 0,
                    time: morningCandles.first?.timeOpen ?? 0,
                    touches: [
                        Touch(index: 0, time: morningCandles.first?.timeOpen ?? 0, closePrice: mid)
                    ]
                )
            ]
        )
    }
}

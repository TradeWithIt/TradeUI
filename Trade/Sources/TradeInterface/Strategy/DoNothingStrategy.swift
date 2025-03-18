import Foundation
import TradingStrategy

public struct DoNothingStrategy: Strategy {
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
        self.indicators = [[:]]
        self.levels = []
        self.distribution = []
    }

    public var patternIdentified: Bool {
        return false
    }
    
    public var patternInformation: [String: Bool] {
        return [:]
    }

    // MARK: - Position Manager & Trade Decision

    public func unitCount(entryBar: Klines, equity: Double, feePerUnit cost: Double) -> Int {
        return 0
    }
    
    public func adjustStopLoss(entryBar: Klines) -> Double? {
        return nil
    }
    
    public func shouldExit(entryBar: Klines) -> Bool {
        return true
    }
}

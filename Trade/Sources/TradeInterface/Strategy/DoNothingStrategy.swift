import Foundation
import TradingStrategy

public struct DoNothingStrategy: Strategy {
    public var id = "com.view.only"
    public var name = "Viewing only"
    public var version: (major: Int, minor: Int, patch: Int) = (1, 0, 0)
    
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

    public func shouldEnterWitUnitCount(
        entryBar: any TradingStrategy.Klines,
        equity: Double,
        feePerUnit cost: Double,
        nextAnnoucment annoucment: Annoucment?
    ) -> Int {
        return 0
    }
    
    public func shouldExit(entryBar: Klines, nextAnnoucment annoucment: Annoucment?) -> Bool {
        return true
    }
    
    public func adjustStopLoss(entryBar: Klines) -> Double? {
        return nil
    }
}

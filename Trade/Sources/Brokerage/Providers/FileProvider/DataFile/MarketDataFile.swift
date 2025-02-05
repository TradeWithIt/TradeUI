import Foundation
import Combine

public protocol MarketDataFile {
    var fileUrl: URL { get }
    func readBars(symbol: Symbol, interval: TimeInterval, speedFactor: Double, loadAllAtOnce: Bool) throws -> AnyPublisher<CandleData, Never>
    func save(strategyName: String, candleData: CandleData)
    func loadCandleData() -> CandleData?
}

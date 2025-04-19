import Foundation
import Brokerage
import TradingStrategy

public protocol CandleFileProvider: Sendable {
    var snapshotsDirectory: URL? { get }
    func save(symbol: Symbol, interval: TimeInterval, bars: [Bar], strategyName: String) throws
    func loadFile(url: URL) throws -> CandleData?
    func loadFileData(url: URL, symbol: Symbol, interval: TimeInterval) throws -> CandleData?
}

extension MarketDataFileProvider: CandleFileProvider {}

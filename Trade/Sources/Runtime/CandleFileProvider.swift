import Foundation
import Brokerage
import TradingStrategy

public protocol CandleFileProvider {
    var snapshotsDirectory: URL? { get }
    func save(symbol: Symbol, interval: TimeInterval, bars: [Bar], strategyName: String) throws
    func loadFile(name: String) throws -> CandleData?
    func loadFileData(forSymbol symbol: Symbol, interval: TimeInterval, fileName: String) throws -> CandleData?
}

extension MarketDataFileProvider: CandleFileProvider {}

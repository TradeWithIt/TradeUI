import Foundation
import Combine

public enum MarketDataKey: String {
    case bufferInfo = "buffer"
    case snapshotDateInfo = "snapshot.date"
    case snapshotPlaybackSpeedInfo = "snapshot.playback.speed"
}

public protocol MarketData {
    init()
    /// Connect Service
    func connect() throws
    /// Requests price history with continues real time updates for asset symbol.
    func marketData(symbol:  Symbol, interval: TimeInterval, userInfo: [String: Any]) throws -> AnyPublisher<CandleData, Never>
    /// Requests price history with continues real time updates for asset.
    /// - Parameters:
    ///   - product: Asset symbol product information
    ///   - interval: Bar interval
    ///   - buffer: Default to 54000 for 1minute
    func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never>
    /// Requests price history snapshot with continues real time updates for asset symbol
    func marketDataSnapshot(
        symbol:  Symbol,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never>
    /// Requests price history snapshot with continues real time updates for asset symbol
    func marketDataSnapshot(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never>
    /// Cancel real time market data updates
    /// - Parameters:
    ///   - symbol: Asset symbol
    ///   - interval: Bar interval
    func unsubscribeMarketData(symbol:  Symbol, interval: TimeInterval)
}

public extension MarketData {
    /// Requests price history with continues real time updates for asset with 1minute bar size and 15h of history.
    /// - Parameter symbol: Asset symbol
    func marketData(symbol:  Symbol) throws -> AnyPublisher<CandleData, Never> {
        try marketData(symbol: symbol, interval: 60, userInfo: [MarketDataKey.bufferInfo.rawValue: 54000])
    }
}

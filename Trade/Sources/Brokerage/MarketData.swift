import Foundation
import Combine

public enum MarketDataKey: String {
    case bufferInfo = "buffer"
    case snapshotFileURL = "snapshot.file.url"
    case snapshotPlaybackSpeedInfo = "snapshot.playback.speed"
}

public protocol MarketData {
    init()
    /// Connect Service
    func connect() throws
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
        contract product: any Contract,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date?,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never>
    /// Cancel real time market data updates
    /// - Parameters:
    ///   - symbol: Asset symbol
    ///   - interval: Bar interval
    func unsubscribeMarketData(contract: any Contract, interval: TimeInterval)
    func quotePublisher(contract product: any Contract) throws -> AnyPublisher<Quote, Never>
}

import Foundation

public enum MarketDataKey: String {
    case bufferInfo = "buffer"
    case snapshotFileURL = "snapshot.file.url"
}

public protocol MarketData: Sendable {
    init()
    /// Connect Service
    func connect() async throws
    func disconnect() async throws
    
    var account: Account? { get }
    /// Requests price history with continues real time updates for asset.
    /// - Parameters:
    ///   - product: Asset symbol product information
    ///   - interval: Bar interval
    ///   - buffer: Default to 54000 for 1minute
    func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AsyncStream<CandleData>
    /// Requests price history snapshot with continues real time updates for asset symbol
    func marketDataSnapshot(
        contract product: any Contract,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date?,
        userInfo: [String: Any]
    ) throws -> AsyncStream<CandleData>
    /// Cancel real time market data updates
    /// - Parameters:
    ///   - symbol: Asset symbol
    ///   - interval: Bar interval
    func unsubscribeMarketData(contract: any Contract, interval: TimeInterval) async throws
    func quotePublisher(contract product: any Contract) throws -> AsyncStream<Quote>
    func tradingHour(_ product: any Contract) async throws -> [TradingHour]
}

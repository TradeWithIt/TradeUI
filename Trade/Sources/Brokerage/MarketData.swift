import Foundation
import Combine

public protocol MarketData {
    init()
    /// Connect Service
    func connect() throws
    /// Requests price history with continues real time updates for asset.
    /// - Parameters:
    ///   - symbol: Asset symbol
    ///   - interval: Bar interval
    ///   - buffer: Default to 54000 for 1minute
    func marketData(symbol:  Symbol, interval: TimeInterval, buffer: TimeInterval) throws -> AnyPublisher<CandleData, Never>
}

public extension MarketData {
    /// Requests price history with continues real time updates for asset with 1minute bar size and 15h of history.
    /// - Parameter symbol: Asset symbol
    func marketData(symbol:  Symbol) throws -> AnyPublisher<CandleData, Never> {
        try marketData(symbol: symbol, interval: 60, buffer: 54000)
    }
}
import Foundation
import Combine

public protocol MarketSearch {
    init()
    /// Connect Service
    func connect() throws
    /// Asset symbol search
    func search(nameOrSymbol symbol: Symbol) throws -> AnyPublisher<[any Contract], Swift.Error>
}

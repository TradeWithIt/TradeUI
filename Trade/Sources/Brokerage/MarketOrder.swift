import Foundation
import Combine

public protocol MarketOrder {
    init()
    /// Connect Service
    func connect() throws
    func makeOrder(symbol: Symbol, action: OrderAction, order: Order) throws
}

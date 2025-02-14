import Foundation
import Combine

public protocol MarketOrder {
    init()
    /// Connect Service
    func connect() throws
    func makeOrder(contract product: any Contract, action: OrderAction, order: Order) throws
}

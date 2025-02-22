import Foundation
import Combine

public protocol MarketOrder {
    init()
    /// Connect Service
    func connect() throws
    
    /// Retrieve All Active Orders
    func getOrders() -> [Order]
    func cancelAllOrders() throws
    
    /// Create Orders
    func makeLimitOrder(
        contract product: any Contract,
        action: OrderAction,
        price: Double,
        quantity: Double
    ) throws
    func makeLimitWithTrailingStopOrder(
        contract product: any Contract,
        action: OrderAction,
        price: Double,
        trailStopPrice: Double,
        quantity: Double
    ) throws
}



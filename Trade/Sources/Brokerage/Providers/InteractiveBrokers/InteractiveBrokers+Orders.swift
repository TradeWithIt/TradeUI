import Foundation
import Combine
import IBKit

extension InteractiveBrokers {
    @discardableResult
    func limitWithTrailingStopOrder(
        contract: IBContract,
        action: IBAction,
        price: Double,
        trailStopPrice: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = account?.name else { throw TradeError.requestError("Missing account identifier")}
        //This will be our main or "parent" order
        var limitOrder = IBOrder.limit(
            price, action: action, quantity: quantity, contract: contract, account: account
        )
        limitOrder.orderID = nextOrderID
        //The parent and children orders will need this attribute set to false to prevent accidental executions.
        //The LAST CHILD will have it set to true,
        limitOrder.transmit = false
        
        var stopOrder = IBOrder.trailingStop(
            stop: trailStopPrice,
            limit: price,
            action: action == .buy ? .sell: .buy,
            quantity: quantity,
            contract: contract,
            account: account
        )
        stopOrder.orderID = nextOrderID
        stopOrder.parentId = limitOrder.orderID
        //In this case, the low side order will be the last child being sent. Therefore, it needs to set this attribute to true
        //to activate all its predecessors
        stopOrder.transmit = true
        return try placeOrder(limitOrder)
            .merge(with: try placeOrder(stopOrder))
            .eraseToAnyPublisher()
    }
    
    @discardableResult
    func limitOrder(
        contract: IBContract,
        action: IBAction,
        price: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = account?.name else { throw TradeError.requestError("Missing account identifier")}
        var limitOrder = IBOrder.limit(
            price, action: action, quantity: quantity, contract: contract, account: account
        )
        limitOrder.orderID = nextOrderID
        return try placeOrder(limitOrder)
    }
    
    @discardableResult
    func trailingStopOrder(
        contract: IBContract,
        action: IBAction,
        parentOrderId: Int = 0,
        price: Double,
        trailStopPrice: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = account?.name else { throw TradeError.requestError("Missing account identifier")}
        var stopOrder = IBOrder.trailingStop(
            stop: trailStopPrice,
            limit: price,
            action: action,
            quantity: quantity,
            contract: contract,
            account: account
        )
        stopOrder.orderID = nextOrderID
        stopOrder.parentId = parentOrderId
        return try placeOrder(stopOrder)
    }
    
    /// sends order to broker
    private func placeOrder(_ order: IBOrder) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        let requestID = client.nextRequestID
        let publisher =  client.eventFeed
            .setFailureType(to: Swift.Error.self)
            .compactMap { $0 as? IBIndexedEvent }
            .filter { $0.requestID == requestID }
            .tryMap { response -> OrderEvent in
                switch response {
                case let event as OrderEvent:
                    return event
                case let event as IBServerError:
                    throw TradeError.requestError(event.message)
                default:
                    let message = "thsi should never happen but received anyway \(response)"
                    throw TradeError.somethingWentWrong(message)
                }
            }
            .eraseToAnyPublisher()
        
        try client.placeOrder(order.orderID, order: order)
        return publisher
    }
    
    @discardableResult
    func placeIBAlgoExitOrders(
        contract product: any Contract,
        isLong: Bool,
        entryPrice: Double,
        trailStopPrice: Double,
        takeProfitPrice: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = account?.name else { throw TradeError.requestError("Missing account identifier") }
        let contract = self.contract(product)
        let exitOCAGroup = UUID().uuidString
        
        var limitOrder = IBOrder.limit(
            entryPrice, action: isLong ? .buy : .sell, quantity: quantity, contract: contract, account: account
        )
        limitOrder.orderID = nextOrderID
        limitOrder.transmit = false
        
        var stopOrder = IBOrder.trailingStop(
            stop: trailStopPrice,
            limit: entryPrice,
            action: isLong ? .sell : .buy,
            quantity: quantity,
            contract: contract,
            account: account
        )
        stopOrder.parentId = limitOrder.orderID
        stopOrder.orderID = nextOrderID
        stopOrder.ocaGroup = exitOCAGroup
        stopOrder.transmit = false
        
        var takeProfitOrder = IBOrder.limit(
            takeProfitPrice,
            action: isLong ? .sell : .buy,
            quantity: quantity,
            contract: contract,
            account: account
        )
        takeProfitOrder.parentId = limitOrder.orderID
        takeProfitOrder.orderID = nextOrderID
        takeProfitOrder.ocaGroup = exitOCAGroup
        takeProfitOrder.transmit = true
        
        return try placeOrder(limitOrder)
            .merge(with: try placeOrder(stopOrder))
            .merge(with: try placeOrder(takeProfitOrder))
            .eraseToAnyPublisher()
    }
}

public protocol OrderEvent{}
extension IBOrder: OrderEvent {}
extension IBOpenOrder: OrderEvent {}
extension IBOpenOrderEnd: OrderEvent {}
extension IBOrderStatus: OrderEvent {}
extension IBOrderExecution: OrderEvent {}
extension IBOrderExecutionEnd: OrderEvent {}
extension IBOrderCompletion: OrderEvent {}
extension IBOrderCompetionEnd: OrderEvent {}

extension IBOrder: @retroactive @unchecked Sendable {}
extension IBOrder: Order {
    public var symbol: String {  contract.localSymbol ?? contract.symbol }
    public var orderAction: OrderAction { self.action == .buy ? .buy : .sell }
    public var limitPrice: Double? { lmtPrice }
    public var stopPrice: Double? { auxPrice }
    public var totalCount: Double { totalQuantity }
    public var orderStatus: String { orderState.status.rawValue }
    public var timestamp: Date? { orderState.completedTime }
    public var filledCount: Double {
        set {
            filledQuantity = newValue
        }
        get {
            filledQuantity ?? 0
        }
    }
}

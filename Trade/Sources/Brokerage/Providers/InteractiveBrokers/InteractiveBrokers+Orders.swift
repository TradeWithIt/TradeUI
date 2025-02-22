import Foundation
import Combine
import IBKit

public extension InteractiveBrokers {
    func limitWithTrailingStopOrder(
        contract: IBContract,
        action: IBAction,
        price: Double,
        trailStopPrice: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = identifiers.first else { throw TradeError.requestError("Missing account identifier")}
        var limitOrder = IBOrder.limit(
            price, action: action, quantity: quantity, contract: contract, account: account
        )
        limitOrder.orderID = nextOrderID
        
        var stopOrder = IBOrder.trailingStop(
            stopOffset: trailStopPrice,
            action: action == .buy ? .sell: .buy,
            quantity: quantity,
            contract: contract,
            account: account
        )
        stopOrder.orderID = nextOrderID
        stopOrder.parentId = limitOrder.orderID
        
        let limit = try placeOrder(stopOrder)
        let trailingStop = try placeOrder(limitOrder)
        return limit.merge(with: trailingStop).eraseToAnyPublisher()
    }
    
    func limitOrder(
        contract: IBContract,
        action: IBAction,
        price: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = identifiers.first else { throw TradeError.requestError("Missing account identifier")}
        var limitOrder = IBOrder.limit(
            price, action: action, quantity: quantity, contract: contract, account: account
        )
        limitOrder.orderID = nextOrderID
        return try placeOrder(limitOrder)
    }
    
    func trailingStopOrder(
        contract: IBContract,
        action: IBAction,
        parentOrderId: Int = 0,
        trailStopPrice: Double,
        quantity: Double
    ) throws -> AnyPublisher<any OrderEvent, Swift.Error> {
        guard let account = identifiers.first else { throw TradeError.requestError("Missing account identifier")}
        var stopOrder = IBOrder.trailingStop(
            stopOffset: trailStopPrice,
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
        
        try client.placeOrder(requestID, order: order)
        return publisher
    }
}

public protocol OrderEvent{}
extension IBOrder: OrderEvent {}
extension IBOpenOrder: OrderEvent {}
extension IBOrderStatus: OrderEvent {}
extension IBOrderExecution: OrderEvent {}
extension IBOrderExecutionEnd: OrderEvent {}
extension IBOrderCompletion: OrderEvent {}
extension IBOrderCompetionEnd: OrderEvent {}

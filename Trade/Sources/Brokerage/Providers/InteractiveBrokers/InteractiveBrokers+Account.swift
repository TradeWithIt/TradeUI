import Foundation
import Combine
import IBKit

public extension InteractiveBrokers {
    // MARK: - Fetch Active Orders
    func fetchActiveOrders() throws -> AnyPublisher<IBOpenOrder, Swift.Error> {
        let requestID = client.nextRequestID
        let publisher = client.eventFeed
            .setFailureType(to: Swift.Error.self)
            .compactMap { $0 as? IBIndexedEvent }
            .filter { $0.requestID == requestID }
            .tryMap { response -> IBOpenOrder in
                switch response {
                case let event as IBOpenOrder:
                    return event
                case let event as IBServerError:
                    throw TradeError.requestError(event.message)
                default:
                    let message = "thsi should never happen but received anyway \(response)"
                    throw TradeError.somethingWentWrong(message)
                }
            }
            .eraseToAnyPublisher()
        
        try client.requestOpenOrders()
        return publisher
    }
    
    // MARK: - Fetch Open Positions
    func fetchOpenPositions() throws -> AnyPublisher<IBPosition, Swift.Error> {
        let publisher = client.eventFeed
            .setFailureType(to: Swift.Error.self)
            .tryMap { response -> IBPosition in
                switch response {
                case let event as IBPosition:
                    return event
                case let event as IBServerError:
                    throw TradeError.requestError(event.message)
                default:
                    let message = "thsi should never happen but received anyway \(response)"
                    throw TradeError.somethingWentWrong(message)
                }
            }
            .eraseToAnyPublisher()
        
        try client.subscribePositions()
        return publisher
    }
    
    // MARK: - Fetch Account Funds
    func fetchAccountSummary() throws -> AnyPublisher<IBAccountSummary, Swift.Error> {
        let requestID = client.nextRequestID
        let publisher = client.eventFeed
            .setFailureType(to: Swift.Error.self)
            .compactMap { $0 as? IBIndexedEvent }
            .filter { $0.requestID == requestID }
            .tryMap { response -> IBAccountSummary in
                switch response {
                case let event as IBAccountSummary:
                    return event
                case let event as IBServerError:
                    throw TradeError.requestError(event.message)
                default:
                    let message = "thsi should never happen but received anyway \(response)"
                    throw TradeError.somethingWentWrong(message)
                }
            }
            .eraseToAnyPublisher()
        
        try client.subscribeAccountSummary(requestID)
        return publisher
    }
}

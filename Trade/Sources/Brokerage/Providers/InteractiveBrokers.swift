import Foundation
import Combine
import IBKit

public class InteractiveBrokers: Market {
    private struct Asset: Hashable {
        var symbol: String
        var interval: TimeInterval
    }
    
    private let client = IBClient.live(id: 0, type: .gateway)
    private var subscriptions: [AnyCancellable] = []
    private var identifiers: Set<String> = []
    private var unsubscribeMarketData: Set<Asset> = []
    
    deinit {
        client.disconnect()
    }
    
    required public init() {
        client.eventFeed.sink {[weak self] anyEvent in
            switch anyEvent {
            case let event as IBManagedAccounts:
                self?.identifiers.formUnion(event.identifiers)
            default:
                break
            }
        }
        .store(in: &subscriptions)
    }
    
    public func connect() throws {
        try client.connect()
    }
    
    public func search(symbol:  Symbol) {
        do {
            let requestID = client.nextRequestID
            try client.searchSymbols(requestID, nameOrSymbol: "APPL")
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func makeOrder(symbol: Symbol, action: OrderAction, order: Order) throws {
    }
    
    public func unsubscribeMarketData(symbol:  Symbol, interval: TimeInterval) {
        unsubscribeMarketData.insert(Asset(symbol: symbol, interval: interval))
    }
    
    public func marketData(
        symbol:  Symbol,
        interval: TimeInterval,
        buffer: TimeInterval
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract.future(localSymbol: symbol, currency: "USD", exchange: .CME)
        unsubscribeMarketData.remove(Asset(symbol: symbol, interval: interval))
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: .distantFuture)
        )
    }
    
    // MARK: Private IB Type handling
    
    private func unsubscribeMarketData(_ requestID: Int) {
        try? client.cancelHistoricalData(requestID)
    }
    
    private func historicBarPublisher(
        contract: IBContract,
        barSize size: IBBarSize,
        duration: DateInterval
    ) throws -> AnyPublisher<CandleData, Never> {
        let symbol = contract.localSymbol ?? contract.symbol
        let interval: TimeInterval = size.timeInterval
        let requestID = client.nextRequestID
        
        let publisher = client.eventFeed
            .compactMap { $0 as? IBIndexedEvent }
            .filter { $0.requestID == requestID }
            .compactMap {[weak self] response -> CandleData? in
                let asset = Asset(symbol: symbol, interval: interval)
                if let data = self?.unsubscribeMarketData, data.contains(asset) {
                    self?.unsubscribeMarketData.remove(asset)
                    self?.unsubscribeMarketData(requestID)
                    return nil
                }

                switch response {
                case let event as IBPriceHistory:
                    return CandleData(
                        symbol: symbol,
                        interval: interval,
                        bars: event.prices
                            .sorted { $0.date < $1.date }
                            .map { Bar(bar: $0, interval: interval) }
                    )
                case let event as IBPriceBarUpdate:
                    return CandleData(
                        symbol: symbol,
                        interval: interval,
                        bars: [Bar(bar: event.bar, interval: interval)]
                    )
                case let event as IBServerError:
                    // Optionally log the error or handle it differently
                    print("Error: \(event.message)")
                    return nil
                default:
                    let message = "This should never happen but received anyway \(response)"
                    print("Unexpected event: \(message)")
                    return nil
                }
                
            }
            .eraseToAnyPublisher()
        
        try client.requestPriceHistory(
            requestID,
            contract: contract,
            barSize: size,
            barSource: IBBarSource.trades,
            lookback: duration
        )
        
        return publisher
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
                    throw Error.requestError(event.message)
                default:
                    let message = "thsi should never happen but received anyway \(response)"
                    throw Error.somethingWentWrong(message)
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

extension Bar {
    init(bar update: IBPriceBar, interval: TimeInterval) {
        self.init(
            timeOpen: update.date.timeIntervalSince1970,
            interval: interval,
            priceOpen: update.open,
            priceHigh: update.high,
            priceLow: update.low,
            priceClose: update.close
        )
    }
}

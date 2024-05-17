import Foundation
import Combine
import IBKit

public class InteractiveBrokers: Market {
    private let client = IBClient.live(id: 0, type: .gateway)
    private var subscriptions: [AnyCancellable] = []
    private var identifiers: Set<String> = []
    
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
    
    public func search() {
        do {
            let requestID = client.nextRequestID
            try client.searchSymbols(requestID, nameOrSymbol: "MES")
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func makeOrder(symbol: Symbol, action: OrderAction, order: Order) throws {
        
    }
    
    public func marketData(
        symbol:  Symbol,
        interval: TimeInterval,
        buffer: TimeInterval
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract.future(localSymbol: symbol, currency: "USD", exchange: .CME)
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: .distantFuture)
        )
    }
    
    // MARK: Private IB Type handling
    
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
            .compactMap { response -> CandleData? in
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

public extension IBContract {
    /*:
    ## Futures
    A regular futures contract is commonly defined using underlying asset symbol, currency and expiration date or expiration year and month.
    */
    static let miniSPX = IBContract.future("ME", currency: "USD", expiration: try! Date.futureExpiration(year: 2024, month: 12), exchange: .CME)
//    static let microSPX = IBContract.future("MES", currency: "USD", expiration: try! Date.futureExpiration(year: 2024, month: 12), exchange: .CME)

    /*:
    Another possibility is to use initializer with local symbol which defines product's undelying asset and expiration. The future contract local symbol consists of
    - Asset symbol
    - Month code: F - January, G - February, H - March, J - April, K - May, M - June, N - July, Q - August, U - September, V - October, X - November, Z - December
    - Last digit of the expiration year
    */
    static let microSPX = IBContract.future(localSymbol: "MESM4", currency: "USD", exchange: .CME)
    
    
    static let aapl = IBContract.equity("AAPL", currency: "USD")
    static let cryptoEth = IBContract.crypto("ETH", currency: "USD", exchange: .PAXOS)
    static let dax = IBContract.index("DAX", currency: "EUR", exchange: .EUREX)
    static let sp500 = IBContract.future(localSymbol: "MESM4", currency: "USD", exchange: .SMART)
    static let russell2000 = IBContract.future(localSymbol: "M2KM4", currency: "USD", exchange: .CME)
    static let NASDAQ100 = IBContract.future(localSymbol: "MNQM4", currency: "USD", exchange: .CME)
    static let Dow = IBContract.future(localSymbol: "MYMM4", currency: "USD", exchange: .CME)
}

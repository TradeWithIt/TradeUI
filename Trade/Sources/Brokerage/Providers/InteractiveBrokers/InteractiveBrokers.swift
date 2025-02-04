import Foundation
import Combine
import IBKit

public class InteractiveBrokers: Market {
    private struct Asset: Hashable {
        var symbol: String
        var interval: TimeInterval
    }
    
    private let client = IBClient.paper(id: 0, type: .gateway)
    private var subscriptions: [AnyCancellable] = []
    private var identifiers: Set<String> = []
    private var unsubscribeMarketData: Set<Asset> = []
    
    deinit {
        client.disconnect()
    }
    
    required public init() {
        client.eventFeed.sink {[weak self] anyEvent in
            print(anyEvent.self)
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
        do {
            try client.connect()
        } catch {
            print("🔴 failed to connect to Interactive Brokers:", error)
        }
    }
    
    public func search(nameOrSymbol symbol: Symbol) throws -> AnyPublisher<[any Contract], Swift.Error> {
        try Product.fetchProducts(symbol: symbol, productType: [.stock])
            .map { products in
                products as [any Contract]
            }
            .eraseToAnyPublisher()
    }
    
    public func makeOrder(symbol: Symbol, action: OrderAction, order: Order) throws {
    }
    
    public func unsubscribeMarketData(symbol:  Symbol, interval: TimeInterval) {
        unsubscribeMarketData.insert(Asset(symbol: symbol, interval: interval))
    }
    
    public func marketData(
        symbol:  Symbol,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let buffer = userInfo[MarketDataKey.bufferInfo.rawValue] as? TimeInterval ?? interval
        let contract = IBContract.equity(symbol, currency: "USD")
        unsubscribeMarketData.remove(Asset(symbol: symbol, interval: interval))
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: .distantFuture)
        )
    }
    
    public func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract.crypto(
            product.localSymbol,
            currency: product.currency,
            exchange: IBExchange(rawValue: product.exchangeId) ?? .CME
        )
        let buffer = userInfo[MarketDataKey.bufferInfo.rawValue] as? TimeInterval ?? interval
        unsubscribeMarketData.remove(Asset(symbol: product.localSymbol, interval: interval))
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: .distantFuture)
        )
    }
    
    public func marketDataSnapshot(
        symbol: Symbol,
        type: String,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract(
            symbol: symbol,
            secType: IBSecuritiesType(rawValue: type) ?? .stock,
            currency: "USD",
            exchange: .PAXOS
        )
        let buffer = userInfo[MarketDataKey.bufferInfo.rawValue] as? TimeInterval ?? interval
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: Date())
        )
    }
    
    public func marketDataSnapshot(
        contract product: any Contract,
        type: String,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract(
            symbol: product.localSymbol,
            secType: IBSecuritiesType(rawValue: type) ?? .stock,
            currency: product.currency,
            exchange: IBExchange(rawValue: product.exchangeId) ?? .CME
        )
        let buffer = userInfo[MarketDataKey.bufferInfo.rawValue] as? TimeInterval ?? interval
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: Date())
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
                    print("Error: \(event.message)")
                    return nil
                default:
                    print("Unexpected event: \(response)")
                    return nil
                }
            }
            .eraseToAnyPublisher()
        
        try client.requestPriceHistory(
            requestID,
            contract: contract,
            barSize: size,
            barSource: IBBarSource.trades,
//            barSource: IBBarSource.aggTrades,
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

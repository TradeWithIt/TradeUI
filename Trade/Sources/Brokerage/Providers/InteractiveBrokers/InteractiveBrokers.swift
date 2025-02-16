import Foundation
import Combine
import IBKit

public class InteractiveBrokers: Market {
    private struct Asset: Hashable {
        var contract: any Contract
        var interval: TimeInterval
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(contract)
            hasher.combine(interval)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.contract.hashValue == rhs.contract.hashValue
            && lhs.interval == rhs.interval
        }
    }
    
//    private let client = IBClient.live(id: 0, type: .gateway)
    private let client = IBClient.paper(id: 0, type: .gateway)
    private var subscriptions: [AnyCancellable] = []
    private var identifiers: Set<String> = []
    private var unsubscribeMarketData: Set<Asset> = []
    private var unsubscribeQuote: Set<IBContract> = []
    
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
        do {
            try client.connect()
        } catch {
            print("🔴 failed to connect to Interactive Brokers:", error)
        }
    }
    
    // MARK: - Market Symbol Search
    
    public func search(nameOrSymbol symbol: Symbol) throws -> AnyPublisher<[any Contract], Swift.Error> {
        try Product.fetchProducts(symbol: symbol, productType: [.stock])
            .map { products in
                products as [any Contract]
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: Market Data
    
    public func unsubscribeMarketData(contract: any Contract, interval: TimeInterval) {
        unsubscribeMarketData.insert(Asset(contract: contract, interval: interval))
    }
    
    public func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract(
            symbol: product.symbol,
            secType: IBSecuritiesType(rawValue: product.type) ?? .stock,
            currency: product.currency,
            exchange: IBExchange(rawValue: product.exchangeId) ?? .SMART
        )
        let buffer = userInfo[MarketDataKey.bufferInfo.rawValue] as? TimeInterval ?? interval
        let barSize = IBBarSize(timeInterval: interval)
        unsubscribeMarketData.remove(Asset(contract: product, interval: interval))
            
        return try historicBarPublisher(
            contract: contract,
            barSize: barSize,
            duration: DateInterval(start: Date(timeIntervalSinceNow: -buffer), end: .distantFuture)
        )
    }
    
    public func marketDataSnapshot(
        contract product: any Contract,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date? = nil,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let contract = IBContract(
            symbol: product.symbol,
            secType: IBSecuritiesType(rawValue: product.type) ?? .stock,
            currency: product.currency,
            exchange: IBExchange(rawValue: product.exchangeId) ?? .CME
        )
        return try historicBarPublisher(
            contract: contract,
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: startDate, end: endDate ?? Date())
        )
    }
    
    // MARK: Private IB Type handling
    
    private func unsubscribeMarketData(_ requestID: Int) {
        try? client.cancelHistoricalData(requestID)
    }
    
    // publishes one time event
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
                let asset = Asset(contract: contract, interval: interval)
                if let data = self?.unsubscribeMarketData, data.contains(asset) {
                    self?.unsubscribeMarketData.remove(asset)
                    self?.unsubscribeQuote.insert(contract)
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
    
    // MARK: Market Order
    
    public func makeOrder(contract product: any Contract, action: OrderAction, order: Order) throws {
        
    }
    
    private func unsubscribeQuote(_ requestID: Int) {
        try? client.unsubscribeMarketData(requestID)
    }
    
    /// publishes live bid, ask, last snapshorts taken every 250ms of requested contract
    /// - Parameters:
    /// - contract: security description
    /// - extendedSession: include data from extended trading hours
    public func quotePublisher(contract product: any Contract) throws -> AnyPublisher<Quote, Never> {
        let requestID = client.nextRequestID
        let contract = IBContract(
            symbol: product.symbol,
            secType: IBSecuritiesType(rawValue: product.type) ?? .stock,
            currency: product.currency,
            exchange: IBExchange(rawValue: product.exchangeId) ?? .CME
        )
        let publisher =  client.eventFeed
            .compactMap { $0 as? IBIndexedEvent }
            .filter { $0.requestID == requestID }
            .compactMap {[weak self] response -> Quote? in
                if let self, self.unsubscribeQuote.contains(contract) {
                    self.unsubscribeQuote(requestID)
                    self.unsubscribeQuote.remove(contract)
                }
                
                switch response {
                case let event as IBTick:
                    return Quote(tick: event, contract: contract)
                case let event as IBServerError:
                    print("Error: \(event.message)")
                    return nil
                default:
                    return nil
                }
            }
            .eraseToAnyPublisher()
        
        let request = IBMarketDataRequest(requestID: requestID, contract: contract)
        try client.send(request: request)
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

extension IBContract: @retroactive Hashable {}
extension IBContract: @retroactive Equatable {}
extension IBContract: Contract {
    public var type: String {
        self.securitiesType.rawValue
    }
    
    public var exchangeId: String {
        self.exchange?.rawValue ?? ""
    }
}

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

extension Quote {
    init?(tick: IBTick, contract: IBContract) {
        let context: Quote.Context
        switch tick.type {
        case .BidPrice: context = .bidPrice
        case .AskPrice: context = .askPrice
        case .LastPrice: context = .lastPrice
        case .Volume: context = .volume
        default: return nil
        }
        self.init(
            contract: contract,
            date: tick.date,
            type: context,
            value: context == .volume ? tick.value * 100 : tick.value
        )
    }
}

import Foundation
import Combine
import IBKit

public class InteractiveBrokers: @unchecked Sendable, Market {
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
//    let client = IBClient.paper(id: 0, type: .gateway)
    let client = IBClient.paper(id: 0, type: .gateway)
    private let queue = DispatchQueue(label: "InteractiveBrokers.syncQueue", attributes: .concurrent)
    private var _subscriptions: [AnyCancellable] = []
    private var _accounts: [String: Account] = [:]
    
    public var subscriptions: [AnyCancellable] {
        get {
            queue.sync { _subscriptions }
        }
        set {
            queue.async(flags: .barrier) { self._subscriptions = newValue }
        }
    }
    
    public var accounts: [String: Account] {
        get {
            queue.sync { _accounts }
        }
        set {
            queue.async(flags: .barrier) { self._accounts = newValue }
        }
    }
    
    public var account: Account? {
        queue.sync { _accounts.first?.value }
    }
    
    /// Return next valid request identifier you should use to make request or subscription
    private var _nextOrderId: Int = 0
    public var nextOrderID: Int {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let utcComponents = calendar.dateComponents(in: .gmt, from: now)
        
        guard let day = utcComponents.day,
              let hour = utcComponents.hour,
              let minute = utcComponents.minute,
              let second = utcComponents.second else { return _nextOrderId }
        
        // Construct unique order ID: day + hour + minute + second + _nextOrderId
        let orderID = Int("\(String(format: "%02d", day))\(String(format: "%02d", hour))\(String(format: "%02d", minute))\(String(format: "%02d", second))\(String(format: "%d", _nextOrderId))") ?? _nextOrderId
        
        _nextOrderId += 1
        return orderID
    }
    
    private var unsubscribeMarketData: Set<Asset> = []
    private var unsubscribeQuote: Set<IBContract> = []
    
    deinit {
        _subscriptions.forEach { $0.cancel() }
        _subscriptions.removeAll()
        client.disconnect()
    }
    
    required public init() {
        client.eventFeed.sink {[weak self] anyEvent in
            guard let self else { return }
            switch anyEvent {
            case let event as IBManagedAccounts:
                event.identifiers.forEach { accountId in
                    self.startListening(accountId: accountId)
                }
            case let event as IBAccountSummary:
                self.updateAccountData(event: event)
            case let event as IBAccountUpdate:
                self.updateAccountData(event: event)
            case let event as IBPosition:
                self.updatePositions(event)
            case let event as IBPositionPNL:
                self.updatePositions(event)
            case let event as IBPortfolioValue:
                self.updatePortfolio(event)
            case let event as OrderEvent:
                self.updateAccountOrders(event: event)
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
    
    func contract(_ product: any Contract) -> IBContract {
        let contract: IBContract
        if product.type == IBSecuritiesType.future.rawValue {
            contract = IBContract.future(
                localSymbol: product.symbol,
                currency: product.currency,
                exchange: IBExchange(rawValue: product.exchangeId) ?? .CME
            )
        } else {
            contract = IBContract(
                symbol: product.symbol,
                secType: IBSecuritiesType(rawValue: product.type) ?? .stock,
                currency: product.currency,
                exchange: IBExchange(rawValue: product.exchangeId) ?? .SMART
            )
        }
        return contract
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
        let contract = self.contract(product)
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
        try historicBarPublisher(
            contract: self.contract(product),
            barSize: IBBarSize(timeInterval: interval),
            duration: DateInterval(start: startDate, end: endDate ?? Date())
        )
    }
    
    public func tradingHour(_ product: any Contract) async throws -> [TradingHour] {
        let details = try await contractDetails(product)
        return details.liquidHours?.map {
            TradingHour(open: $0.open, close: $0.close, status: $0.status.rawValue)
        } ?? []
    }
    
    public func unitFee(_ product: any Contract) async throws -> [TradingHour] {
        let details = try await contractDetails(product)
        return details.liquidHours?.map {
            TradingHour(open: $0.open, close: $0.close, status: $0.status.rawValue)
        } ?? []
    }
    
    private func contractDetails(_ product: any Contract) async throws -> IBContractDetails {
        let requestID = client.nextRequestID
        let request = IBContractDetailsRequest(requestID: requestID, contract: self.contract(product))
        try client.send(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            var subscription: AnyCancellable?

            subscription = self.client.eventFeed
                .setFailureType(to: Swift.Error.self)
                .compactMap { $0 as? IBIndexedEvent }
                .filter { $0.requestID == requestID }
                .compactMap { $0 as? IBContractDetails }
                .sink(
                    receiveCompletion: { completion in
                        self.subscriptions.removeAll { $0 === subscription }
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { value in
                        self.subscriptions.removeAll { $0 === subscription }
                        continuation.resume(returning: value)
                    }
                )

            if let sub = subscription {
                self.subscriptions.append(sub)
            }
        }
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
    
    public func cancelAllOrders() throws {
        try client.cancelAllOrders()
    }
    
    public func cancelOrder(orderId: Int) throws {
        try client.cancelOrder(orderId)
    }
    
    public func makeLimitOrder(
        contract product: any Contract,
        action: OrderAction,
        price: Double,
        quantity: Double
    ) throws {
        try limitOrder(
            contract: self.contract(product),
            action: action == .buy ? .buy : .sell,
            price: price,
            quantity: quantity
        )
    }
    
    public func makeLimitWithTrailingStopOrder(
        contract product: any Contract,
        action: OrderAction,
        price: Double,
        trailStopPrice: Double,
        quantity: Double
    ) throws {
        try limitWithTrailingStopOrder(
            contract: self.contract(product),
            action: action == .buy ? .buy : .sell,
            price: price,
            trailStopPrice: trailStopPrice,
            quantity: quantity
        )
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
        let contract = self.contract(product)
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
}

extension IBContractDetails: @retroactive @unchecked Sendable {}
extension IBContract: @retroactive Hashable {}
extension IBContract: @retroactive Equatable {}
extension IBContract: @retroactive @unchecked Sendable {}
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
            priceClose: update.close,
            volume: update.volume
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

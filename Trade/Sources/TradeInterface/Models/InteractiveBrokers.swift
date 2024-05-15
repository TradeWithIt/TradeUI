import Foundation
import Combine
import IBKit

public typealias Contract = IBContract
public extension IBContract {
    /*:
    ## Futures
    A regular futures contract is commonly defined using underlying asset symbol, currency and expiration date or expiration year and month.
    */
    static let miniSPX = IBContract.future("ES", currency: "USD", expiration: try! Date.futureExpiration(year: 2024, month: 12), exchange: .CME)

    /*:
    Another possibility is to use initializer with local symbol which defines product's undelying asset and expiration. The future contract local symbol consists of
    - Asset symbol
    - Month code: F - January, G - February, H - March, J - April, K - May, M - June, N - July, Q - August, U - September, V - October, X - November, Z - December
    - Last digit of the expiration year
    */
    static let microSPX = IBContract.future(localSymbol: "MESZ4", currency: "USD", exchange: .CME)
    
    
    static let aapl = IBContract.equity("AAPL", currency: "USD")
    static let cryptoEth = IBContract.crypto("ETH", currency: "USD", exchange: .PAXOS)
    static let dax = IBContract.index("DAX", currency: "EUR", exchange: .EUREX)
    static let sp500 = IBContract.future(localSymbol: "MESM4", currency: "USD", exchange: .SMART)
    static let russell2000 = IBContract.future(localSymbol: "M2KM4", currency: "USD", exchange: .CME)
    static let NASDAQ100 = IBContract.future(localSymbol: "MNQM4", currency: "USD", exchange: .CME)
    static let Dow = IBContract.future(localSymbol: "MYMM4", currency: "USD", exchange: .CME)
}

@Observable
class InteractiveBrokers {
    var onBarUpdate: ((_ requestID: Int, _ bars: [IBPriceBar]) -> Void)?
    
    private let client = IBClient.live(id: 0, type: .gateway)
    private var subscriptions: [AnyCancellable] = []
    private var identifiers: [String] = []
    
    deinit {
        client.disconnect()
    }
    
    init() {
        client.eventFeed.sink {[weak self] anyEvent in
            switch anyEvent {
            case let event as IBManagedAccounts:
                print("IBManagedAccounts", event)
                self?.identifiers = event.identifiers
            case let event as IBPriceHistory:
                self?.onBarUpdate?(event.requestID, event.prices)
                print(String(repeating: "-", count: 30))
            case let event as IBPriceBarUpdate:
                print("IBPriceBarUpdate", event)
                self?.onBarUpdate?(event.requestID, [event.bar])
            case let event as IBTick:
                print("IBTick", event)
            case let event as IBContractSearchResult:
                print("IBContractSearchResult", event)
            default:
                print(anyEvent)
            }
        }
        .store(in: &subscriptions)
    }
    
    func connect() {
        do {
            try client.connect()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func search() {
        do {
            let requestID = client.nextRequestID
            try client.searchSymbols(requestID, nameOrSymbol: "MES")
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func makeOrder(
        symbol: String,
        secType: String = "FUT",
        exchange: String? = nil,
        action: IBAction,
        totalQuantity: Double
    ) throws {
        guard let account = identifiers.first else { return }
        let requestID = client.nextRequestID
        let contract: IBContract = .init(
            symbol: symbol,
            secType: .init(rawValue: secType) ?? .future,
            currency: "USD",
            exchange: exchange != nil ? .init(rawValue: exchange!) : nil
        )
        try client.placeOrder(
            requestID,
            contract: contract,
            order: .trail(
                trailingPercent: 0.15,
                action: action,
                quantity: 1,
                account: account
            )
        )
    }
    
    public func marketData(_ contract:  IBContract) throws -> Chart {
        let id = try realTimePublisher(for: contract)
        return Chart(
            id: id,
            symbol: contract.symbol
        )
    }
    
    public func marketData(
        _ symbol: String,
        secType: IBSecuritiesType = .crypto,
        exchange: IBExchange? = nil
    ) throws -> Chart {
        let contract: IBContract = .init(
            symbol: symbol,
            secType: secType,
            currency: "USD",
            exchange: exchange
        )
        try historicBarPublisher(
            for: contract,
            barSize: .minute,
            duration: IBDuration(start: Date(timeIntervalSinceNow: -4500), end: Date())
        )
        
        let id = try realTimePublisher(for: contract)
        return Chart(
            id: id,
            symbol: symbol
        )
    }
    
    private func tickPublisher(for contract: IBContract) throws -> Int {
        let requestID = client.nextRequestID
        try client.subscribeMarketData(requestID, contract: contract)
        return requestID
    }
    
    private func realTimePublisher(
        for contract: IBContract
    ) throws -> Int {
        let requestID: Int = client.nextRequestID
        try client.subscribeRealTimeBar(
            requestID,
            contract: contract,
            barSize: .fiveSeconds,
            barSource: .trades
        )
        return requestID
    }
    
    @discardableResult
    private func historicBarPublisher(
        for contract: IBContract,
        barSize size: IBBarSize = .minute,
        duration: IBDuration
    ) throws -> Int {
        let requestID = client.nextRequestID
        try client.requestPriceHistory(
            requestID,
            contract: contract,
            barSize: size,
            barSource: IBBarSource.aggTrades,
            lookback: duration
        )
        return requestID
    }
}

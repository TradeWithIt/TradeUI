import Foundation

public struct Contract {
    public let symbol: String
    public let type: String?
    public let primaryExchange: String?
    public let currency: String
    
    init(symbol: String, type: String? = nil, primaryExchange: String? = nil, currency: String) {
        self.symbol = symbol
        self.type = type
        self.primaryExchange = primaryExchange
        self.currency = currency
    }
}

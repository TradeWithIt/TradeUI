import Foundation

public protocol Contract: Hashable {    
    var type: String { get }
    var symbol: String { get }
    var exchangeId: String { get }
    var currency: String { get }
}

extension Contract {
    public var label: String {
        "\(type) \(symbol) \(currency) \(exchangeId)"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(symbol)
        hasher.combine(exchangeId)
        hasher.combine(currency)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type
        && lhs.symbol == rhs.symbol
        && lhs.exchangeId == rhs.exchangeId
        && lhs.currency == rhs.currency
    }
}

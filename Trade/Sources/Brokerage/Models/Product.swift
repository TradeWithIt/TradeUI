import Foundation

public protocol Contract: Hashable {
    var id: String { get }
    var label: String { get }
    
    var type: String { get }
    var symbol: String { get }
    var exchangeId: String { get }
    var localSymbol: String { get }
    var currency: String { get }
}

extension Contract {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(symbol)
        hasher.combine(exchangeId)
        hasher.combine(localSymbol)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.type == rhs.type
        && lhs.symbol == rhs.symbol
        && lhs.exchangeId == rhs.exchangeId
        && lhs.localSymbol == rhs.localSymbol
    }
}

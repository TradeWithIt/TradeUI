import Foundation

public enum OrderAction: String {
    case buy = "Buy"
    case sell = "Sell"
}

public protocol Order {
    var orderID: Int { get }
    var symbol: String { get }
    var orderAction: OrderAction { get }
    var totalQuantity: Double { get }
    var filledCount: Double { get }
    var totalCount: Double { get }
    var limitPrice: Double? { get }
    var stopPrice: Double? { get }
    var orderStatus: String { get }
    var timestamp: Date? { get }
}

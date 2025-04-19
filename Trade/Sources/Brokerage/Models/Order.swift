import Foundation

public enum OrderAction: String, Sendable {
    case buy = "Buy"
    case sell = "Sell"
}

public protocol Order: Sendable {
    var orderID: Int { get }
    var symbol: String { get }
    var orderAction: OrderAction { get }
    var totalQuantity: Double { get set }
    var filledCount: Double { get set }
    var totalCount: Double { get }
    var limitPrice: Double? { get }
    var stopPrice: Double? { get }
    var orderStatus: String { get }
    var timestamp: Date? { get }
}

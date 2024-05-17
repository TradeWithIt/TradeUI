import Foundation

public enum OrderAction: String {
    case buy = "Buy"
    case sell = "Sell"
}

public struct Order {
    public let quantiy: Int
    public let takeProfit: Int
    public let stopLoss: Int
}

import Foundation

public struct Position: Sendable {
    public let type: String
    public let symbol: String
    public let exchangeId: String
    public let currency: String
    public var contractID: Int
    public var quantity: Double
    public var marketValue: Double = 0
    public var averageCost: Double = 0
    public var realizedPNL: Double = 0
    public var unrealizedPNL: Double = 0
}

public extension Position {
    var label: String {
        "\(symbol) \(currency) \(exchangeId) \(type)"
    }
}


import Foundation

public struct Position {
    public let type: String
    public let symbol: String
    public let exchangeId: String
    public let currency: String
    public let quantity: Double
    public let marketValue: Double
    public let averageCost: Double
    public let realizedPNL: Double
    public let unrealizedPNL: Double
}

public extension Position {
    var label: String {
        "\(symbol) \(currency) \(exchangeId) \(type)"
    }
}


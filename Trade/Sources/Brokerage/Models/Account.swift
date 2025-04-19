import Foundation

public struct Account: Sendable {
    public var availableFunds: Double
    public var buyingPower: Double
    public var currency: String?
    public var excessLiquidity: Double
    public var initialMargin: Double
    public var maintenanceMargin: Double
    public var leverage: Double
    public var name: String
    public var netLiquidation: Double
    public var updatedAt: Date?

    public var cashBook: [Balance]
    public var orders: [Int: Order]
    public var positions: [Position]

    public init(name: String) {
        self.name = name
        self.availableFunds = 0.0
        self.buyingPower = 0.0
        self.currency = nil
        self.excessLiquidity = 0.0
        self.initialMargin = 0.0
        self.maintenanceMargin = 0.0
        self.leverage = 0.0
        self.netLiquidation = 0.0
        self.updatedAt = nil
        self.cashBook = []
        self.orders = [:]
        self.positions = []
    }
}

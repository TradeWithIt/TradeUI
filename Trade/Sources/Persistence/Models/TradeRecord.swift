import Foundation

public struct TradeRecord: Sendable, Codable, Identifiable {
    public var id: UUID
    public var symbol: String
    public var strategy: String
    public var entryPrice: Double
    public var buyingPowerOnEntry: Double
    public var entryTime: Date
    public var decision: String
    public var exitPrice: Double?
    public var buyingPowerOnExit: Double?
    public var exitTime: Date?
    public var entrySnapshot: [Candle]
    public var exitSnapshot: [Candle]?

    public init(
        id: UUID,
        symbol: String,
        strategy: String,
        entryPrice: Double,
        buyingPowerOnEntry: Double,
        entryTime: Date,
        decision: String,
        exitPrice: Double? = nil,
        buyingPowerOnExit: Double? = nil,
        exitTime: Date? = nil,
        entrySnapshot: [Candle],
        exitSnapshot: [Candle]? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.strategy = strategy
        self.entryPrice = entryPrice
        self.entryTime = entryTime
        self.decision = decision
        self.exitPrice = exitPrice
        self.exitTime = exitTime
        self.entrySnapshot = entrySnapshot
        self.exitSnapshot = exitSnapshot
        self.buyingPowerOnEntry = buyingPowerOnEntry
        self.buyingPowerOnExit = buyingPowerOnExit
    }
    
    public static let databaseTableName = "trades"
    
    var entrySnapshotJSON: String? {
        try? String(data: JSONEncoder().encode(entrySnapshot), encoding: .utf8)
    }
    
    var exitSnapshotJSON: String? {
        guard let snapshot = exitSnapshot else { return nil }
        return try? String(data: JSONEncoder().encode(snapshot), encoding: .utf8)
    }
}

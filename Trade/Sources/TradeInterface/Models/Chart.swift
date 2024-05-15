import Foundation

public struct Chart: Codable, Hashable {
    public let id: Int
    public let symbol: String
    public let interval: TimeInterval
    
    public init(id: Int, symbol: String, interval: TimeInterval = 60) {
        self.id = id
        self.symbol = symbol
        self.interval = interval
    }
}

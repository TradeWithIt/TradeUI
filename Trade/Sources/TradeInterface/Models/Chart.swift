import Foundation

public struct Chart: Codable, Hashable {
    public let id: Int
    public let symbol: String
    
    public init(id: Int, symbol: String) {
        self.id = id
        self.symbol = symbol
    }
}

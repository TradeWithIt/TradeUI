import Foundation
import TradingStrategy

public extension Array {
    func chunks(_ chunkSize: Int) -> [[Element]] {
        guard chunkSize < count else { return self.map({ [$0] }) }
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

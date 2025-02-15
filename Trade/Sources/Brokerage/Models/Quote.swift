import Foundation
import IBKit

public struct Quote: Equatable {
    public enum Context: Int {
        case bidPrice
        case askPrice
        case lastPrice
        case volume
    }
    
    public var contract: any Contract
    public var date: Date
    public var type: Context
    public var value: Double
    
    public static func == (lhs: Quote, rhs: Quote) -> Bool {
        lhs.date == rhs.date &&
        lhs.type == rhs.type &&
        lhs.value == rhs.value &&
        lhs.contract.hashValue == rhs.contract.hashValue
    }
}

import Foundation
import IBKit

public struct Quote: Sendable, Equatable {
    public enum Context: Int, Sendable {
        case bidPrice
        case askPrice
        case lastPrice
        case volume
    }
    
    public var contract: any Contract
    public var date: Date
    public var type: Context?
    public var value: Double?

    public var bidPrice: Double?
    public var askPrice: Double?
    public var lastPrice: Double?
    public var volume: Double?

    public init(
        contract: any Contract,
        date: Date,
        type: Context? = nil,
        value: Double? = nil,
        bidPrice: Double? = nil,
        askPrice: Double? = nil,
        lastPrice: Double? = nil,
        volume: Double? = nil
    ) {
        self.contract = contract
        self.date = date
        self.type = type
        self.value = value
        self.bidPrice = bidPrice
        self.askPrice = askPrice
        self.lastPrice = lastPrice
        self.volume = volume
    }
    
    public static func == (lhs: Quote, rhs: Quote) -> Bool {
        lhs.date == rhs.date &&
        lhs.contract.hashValue == rhs.contract.hashValue &&
        lhs.bidPrice == rhs.bidPrice &&
        lhs.askPrice == rhs.askPrice &&
        lhs.lastPrice == rhs.lastPrice &&
        lhs.volume == rhs.volume
    }
}

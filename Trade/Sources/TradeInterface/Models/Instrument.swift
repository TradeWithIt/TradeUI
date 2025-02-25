import Foundation
import Brokerage

public struct Asset: Codable, Hashable {
    var instrument: Instrument
    var interval: TimeInterval
    
    var id: String {
        "\(instrument.label):\(interval)"
    }
}

struct Instrument: Codable, Contract {
    var type: String
    var symbol: String
    var exchangeId: String
    var currency: String
}

extension Instrument {
    // MARK: Equity
    static var CBA: Instrument {
        Instrument(
            type: "STK",
            symbol: "CBA",
            exchangeId: "ASX",
            currency: "AUD"
        )
    }
    
    static var APPL: Instrument {
        Instrument(
            type: "STK",
            symbol: "AAPL",
            exchangeId: "SMART",
            currency: "USD"
        )
    }
    
    // MARK: Cryptocurrency
    
    static var BTC: Instrument {
        Instrument(
            type: "CRYPTO",
            symbol: "BTC",
            exchangeId: "PAXOS",
            currency: "USD"
        )
    }
    
    static var ETH: Instrument {
        Instrument(
            type: "CRYPTO",
            symbol: "ETH",
            exchangeId: "PAXOS",
            currency: "USD"
        )
    }
    
    // MARK: Futures
    
    /// Micro E-Mini S&P 500
    static var MESM4: Instrument {
        Instrument(
            type: "FUT",
            symbol: "MESH5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// E-Mini S&P 500
    static var ESM4: Instrument {
        Instrument(
            type: "FUT",
            symbol: "ESH5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// Micro E-mini Russell 2000
    static var M2KM4: Instrument {
        Instrument(
            type: "FUT",
            symbol: "M2KH5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// E-Mini Russell 2000
    static var RTYM4: Instrument {
        Instrument(
            type: "FUT",
            symbol: "RTYH5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
}

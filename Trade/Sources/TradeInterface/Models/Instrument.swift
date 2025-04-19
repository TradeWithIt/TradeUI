import Foundation
import Brokerage

public struct Asset: Codable, Hashable {
    var instrument: Instrument
    var interval: TimeInterval
    var strategyName: String
    
    var id: String {
        "\(strategyName)\(instrument.label):\(interval)"
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
    
    /// NQ
    static var NQ: Instrument {
        Instrument(
            type: "FUT",
            symbol: "NQM5",
            exchangeId: "CME",
            currency: "USD"
        )
    }

    
    /// Micro E-Mini S&P 500
    static var MES: Instrument {
        Instrument(
            type: "FUT",
            symbol: "MESM5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// E-Mini S&P 500
    static var ES: Instrument {
        Instrument(
            type: "FUT",
            symbol: "ESM5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// Micro E-mini Russell 2000
    static var M2K: Instrument {
        Instrument(
            type: "FUT",
            symbol: "M2KM5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
    
    /// E-Mini Russell 2000
    static var RTY: Instrument {
        Instrument(
            type: "FUT",
            symbol: "RTYM5",
            exchangeId: "CME",
            currency: "USD"
        )
    }
}

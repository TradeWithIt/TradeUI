import Foundation

public struct TradingHour {
    public var open: Date
    public var close: Date
    public var status: String
}

public extension [TradingHour] {
    func isMarketOpen() -> (isOpen: Bool, timeUntilClose: TimeInterval?) {
        let now = Date()
        for session in self where session.status == "OPEN" {
            if now >= session.open && now <= session.close {
                let timeUntilClose = session.close.timeIntervalSince(now)
                return (true, timeUntilClose)
            }
        }
        return (false, nil)
    }
}

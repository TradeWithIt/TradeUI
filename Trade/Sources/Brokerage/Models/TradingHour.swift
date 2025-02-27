import Foundation

public struct TradingHour: Equatable {
    public var open: Date
    public var close: Date
    public var status: String
}

public extension [TradingHour] {
    func isMarketOpen() -> (isOpen: Bool, timeUntilChange: TimeInterval?) {
        let now = Date()
        var earliestOpenTime: TimeInterval? = nil
        for session in self where session.status == "OPEN" {
            if now >= session.open && now <= session.close {
                return (true, session.close.timeIntervalSince(now))
            }
            
            if now < session.open {
                let timeUntilOpen = session.open.timeIntervalSince(now)
                if earliestOpenTime == nil || timeUntilOpen < earliestOpenTime! {
                    earliestOpenTime = timeUntilOpen
                }
            }
        }
        
        return (false, earliestOpenTime)
    }
}

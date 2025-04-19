import Foundation

public struct TradingHour: Sendable, Equatable {
    public var open: Date
    public var close: Date
    public var status: String
}

public extension [TradingHour] {
    func isMarketOpen() -> (isOpen: Bool, timeUntilChange: TimeInterval?) {
        let now = Date()
        var nextMarketEvent: TimeInterval? = nil
        var isCurrentlyOpen = false
        
        for session in self where session.status == "OPEN" {
            if session.open <= now && now <= session.close {
                isCurrentlyOpen = true
                nextMarketEvent = session.close.timeIntervalSince(now)
                break
            }
            
            if now < session.open {
                let timeUntilOpen = session.open.timeIntervalSince(now)
                if nextMarketEvent == nil || timeUntilOpen < nextMarketEvent! {
                    nextMarketEvent = timeUntilOpen
                }
            }
        }
        
        return (isCurrentlyOpen, nextMarketEvent)
    }
}

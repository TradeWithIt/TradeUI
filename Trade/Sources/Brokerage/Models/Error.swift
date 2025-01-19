import Foundation

public enum TradeError: LocalizedError {
    case requestError(_ details: String)
    case somethingWentWrong(_ details: String)
}

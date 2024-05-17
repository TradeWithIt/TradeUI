import Foundation

public enum Error: LocalizedError {
    case requestError(_ details: String)
    case somethingWentWrong(_ details: String)
}

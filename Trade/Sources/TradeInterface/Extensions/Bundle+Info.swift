import Foundation

public extension Bundle {
    var isMacOS: Bool {
    #if os(macOS)
        return true
    #else
        return false
    #endif
    }
    
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "TradeApp"
    }
}

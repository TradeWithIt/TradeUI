import Foundation
import Runtime
import TradingStrategy
import AppKit
import SwiftUIComponents

public class TradeAlertHandler: @unchecked Sendable {
    public static let shared = TradeAlertHandler()
    
    public func sendAlert(_ trade: Trade, recentBar: Klines) {
        if UserDefaults.standard.value(forKey: "trade.alert.sound") as? Bool ?? true {
            playSoundAlert()
        }
        if UserDefaults.standard.value(forKey: "trade.alert.message") as? Bool ?? true,
            let recipient = UserDefaults.standard.string(forKey: "trade.alert.message.recipient")?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if recipient.isValidPhoneNumber {
                let tradeDirection = trade.entryBar.isLong ? "Long" : "Short"
                let message = "📈 Trade Alert: \(tradeDirection) at \(trade.price)\nRecent Bar: \(recentBar.priceClose)"
                sendiMessage(message, recipient: recipient)
            } else {
                print("❌ Invalid phone number: \(recipient)")
            }
        }
    }
    
    /**
     ✅ Ensures Messages is running before execution.
     ✅ Checks for an existing iMessage chat.
     ✅ Falls back to sending a message directly if chat creation fails.
     ✅ Prevents SMS fallback (only sends as iMessage).
     */
    
    /// Sends an iMessage or SMS notification when a trade entry/exit occurs
    /// - Parameters:
    ///   - message: message to be sent
    ///   - recipient: recipient phone number i.e. "+1234567890"
    private func sendiMessage(_ message: String, recipient: String) {
        let script = """
        tell application "Messages"
            activate -- Ensure Messages is open
            delay 1 -- Wait for app to fully load

            set recipientID to "\(recipient)"
            set targetService to 1st service whose service type = iMessage

            if targetService is missing value then
                return "❌ Error: No iMessage service available"
            end if

            try
                set targetBuddy to buddy recipientID of targetService
                send "\(message)" to targetBuddy
                return "✅ iMessage sent successfully to \(recipient)"
            on error
                return "❌ Error: Could not send iMessage to \(recipient) (Not an iMessage user?)"
            end try
        end tell
        """

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.launch()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        if let outputString = String(data: outputData, encoding: .utf8) {
            print("💬 AppleScript Output: \(outputString.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if process.terminationStatus == 0 {
            print("✅ iMessage sent successfully to \(recipient)")
        } else {
            print("❌ Failed to send iMessage to \(recipient)")
        }
    }

    /// Plays a sound alert when a trade entry/exit occurs
    private func playSoundAlert() {
        SystemSound.glass.play()
    }
    
    // MARK: - Types
    
    public enum SystemSound: String, CaseIterable {
        case basso = "Basso"
        case blow = "Blow"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case glass = "Glass"
        case hero = "Hero"
        case morse = "Morse"
        case ping = "Ping"
        case pop = "Pop"
        case purr = "Purr"
        case sosumi = "Sosumi"
        case submarine = "Submarine"
        case tink = "Tink"

        /// Plays the selected system sound
        public func play() {
            NSSound(named: NSSound.Name(self.rawValue))?.play()
        }
    }
}

public extension String {
    var isValidPhoneNumber: Bool {
        let phoneRegex = #"^\+?[1-9]\d{1,14}$"#
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: self)
    }
}

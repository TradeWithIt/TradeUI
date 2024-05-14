// swift-tools-version: 5.10

import PackageDescription
import Foundation

let package = Package(
    name: "TradeApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TradeInterface", targets: ["TradeInterface"]),
    ],
    dependencies: [
        .package(url: "https://github.com/shial4/SwiftUIComponents.git", branch: "main"),
        .package(url: "https://github.com/TradeWithIt/Strategy.git", branch: "master"),
        .package(url: "https://github.com/TradeWithIt/IBKit.git", branch: "feat/fix-handshake-race-condition"),
        
        // MARK: Trading Strategy
        .package(url: "https://\(gitHubToken()):x-oauth-basic@github.com/TradeWithIt/TradeWithIt.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TradeInterface",
            dependencies: [
                .product(name: "SwiftUIComponents", package: "SwiftUIComponents"),
                .product(name: "TradingStrategy", package: "Strategy"),
                .product(name: "TradeWithIt", package: "TradeWithIt"),
                .product(name: "IBKit", package: "IBKit"),
            ]
        )
    ]
)

// Function to read the 🐙 GitHub personal access token
private func gitHubToken() -> String {
    // Try to read from environment variable
    if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
        return token
    } else {
        // If not found, try to read from .env.spm file
        let filePath = #file
        let fileURL = URL(fileURLWithPath: filePath).deletingLastPathComponent().appendingPathComponent(".env.spm")

        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = contents.split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 && parts[0] == "GITHUB_TOKEN" {
                    return String(parts[1])
                }
            }
        } catch {
            let message = "nor environment variable or .env.spm file has been found"
            print("🔴", message)
            fatalError(message)
        }
    }
    let message = "GitHub token not found in environment variable or .env.spm file"
    print("🔴", message)
    fatalError(message)
}
// swift-tools-version: 5.10

import PackageDescription
import Foundation

let package = Package(
    name: "TradeApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "TradeInterface",
            targets: ["TradeInterface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/shial4/SwiftUIComponents.git", branch: "main"),
//        .package(url: "https://github.com/stensoosaar/IBKit", branch: "main"),
        .package(name: "IBKit", path: "/Users/szymonlorenz/Development/Swift/IB/IBKit"),
        .package(url: "https://github.com/TradeWithIt/ForexFactory", branch: "main"),
        
        // MARK: Trading Strategy
        .package(url: "https://github.com/TradeWithIt/Strategy.git", branch: "master"),
//            .package(name: "Strategy", path: "/Users/szymonlorenz/Development/Swift/Strategy"),
        .package(url: "https://\(gitHubToken()):x-oauth-basic@github.com/shial4/TradeWithIt.git", branch: "master"),
//        .package(name: "TradeWithIt", path: "/Users/szymonlorenz/Development/Swift/TradeWithIt"),
        
        // MARK: Tools
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.1.0"))
    ],
    targets: [
        .target(
            name: "Brokerage",
            dependencies: [
                .product(name: "IBKit", package: "IBKit"),
            ]
        ),
        .target(
            name: "Runtime",
            dependencies: [
                .target(name: "Brokerage"),
                
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "TradeWithIt", package: "TradeWithIt"),
            ]
        ),
        
        .target(
            name: "TradeInterface",
            dependencies: [
                .target(name: "Runtime"),
                .target(name: "Brokerage"),
                
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SwiftUIComponents", package: "SwiftUIComponents"),
                .product(name: "TradingStrategy", package: "Strategy"),
                .product(name: "ForexFactory", package: "ForexFactory"),
            ]
        ),
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

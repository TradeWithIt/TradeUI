// swift-tools-version: 6.1

import PackageDescription
import Foundation

let package = Package(
    name: "TradeApp",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(
            name: "TradeInterface",
            targets: ["TradeInterface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/shial4/SwiftUIComponents.git", branch: "main"),
        .package(url: "https://github.com/stensoosaar/IBKit", branch: "main"),
        .package(url: "https://github.com/TradeWithIt/ForexFactory", branch: "main"),
        
        // MARK: Trading Strategy
        .package(url: "https://github.com/TradeWithIt/Strategy.git", branch: "master"),
        
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
                .target(name: "Persistence"),
                
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "Persistence",
            dependencies: [
                // .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        
        .target(
            name: "TradeInterface",
            dependencies: [
                .target(name: "Runtime"),
                .target(name: "Brokerage"),
                .target(name: "Persistence"),
                
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SwiftUIComponents", package: "SwiftUIComponents"),
                .product(name: "TradingStrategy", package: "Strategy"),
                .product(name: "ForexFactory", package: "ForexFactory"),
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
    ]
)

# **TradeUI**

![Swift](https://img.shields.io/badge/Swift-5.0-orange) ![Platforms](https://img.shields.io/badge/platforms-macOS-blue)

## **Overview**
TradeUI is a comprehensive Swift-based trading interface that integrates real-time market data, executes trades, and provides an intuitive user experience for managing trading activities. This project is structured into modular components, ensuring scalability, maintainability, and flexibility for traders and developers alike.

## **Architecture**
TradeUI is built around several key modules that interact seamlessly to provide a fully functional trading environment. The primary components include:

### **1. Brokerage Module**
Responsible for handling market data retrieval, trade execution, and order management.

- **Market.swift** – Defines market-related structures and provides real-time price updates.
- **MarketData.swift** – Manages historical and live market data required for analysis.
- **MarketOrder.swift** – Facilitates order placement and execution.
- **MarketSearch.swift** – Allows searching for market instruments and assets.

### **2. Runtime Module**
Handles the execution logic, monitoring active trades, and ensuring strategies are adhered to.

- **Watcher.swift** – Observes market conditions, monitors active trades, and executes orders based on defined strategies.

### **3. Trade Interface Module**
Acts as the central controller, managing trade flow and UI integration.

- **TradeManager.swift** – Oversees trade execution, market interaction, and user-initiated actions.

### **4. Strategy Module**
Defines the logic for automated and manual trading strategies.

- **Strategy.swift** – Defines the `Strategy` protocol for implementing trading logic.
- **Phase.swift** – Categorizes market trends into structured phases (e.g., uptrend, downtrend, sideways).
- **Klines.swift** – Represents candlestick data for technical analysis.
- **Scale.swift** – Manages time and price scaling for market analysis.

### **5. ForexFactory Module**
Fetches and integrates economic events for fundamental analysis.

- **ForexFactory.swift** – Retrieves Forex Factory economic events, allowing strategies to adjust based on macroeconomic news.

### **6. Headless Trading Instance**
TradeUI allows running a trading instance without the UI application, enabling execution from the terminal on any supported platform, including macOS, Linux, and Windows.

- **CLI Mode** – Enables trading via command-line interfaces.
- **Cross-Platform Compatibility** – Can run on macOS, Linux, and Windows without requiring a graphical user interface.

### **7. Trade Decision Engine**
Handles trade entries, risk management, profit-taking, and exits.

- **TradeDecisionEngine.swift** – Manages trade lifecycle decisions, from entry to exit.
- **RiskManager.swift** – Implements stop-loss and take-profit mechanisms.
- **PositionManager.swift** – Optimizes trade position sizing based on market conditions.

---

## **📌 Adding Your Own Strategy**
TradeUI **does not include any pre-built strategies**. However, you can create your own **custom strategies** and dynamically load them into TradeUI.

### **Step 1: Create a Strategy Package**
To create your own strategy, use the [Strategy Protocol and Utilities Library](https://github.com/TradeWithIt/Strategy), which provides all the necessary functionality to define and compile trading strategies.

Ensure that your **`Package.swift`** is set up correctly:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyStrategyPackage",
    products: [
        .library(name: "MyStrategyPackage", type: .dynamic, targets: ["MyStrategyPackage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/TradeWithIt/Strategy.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MyStrategyPackage",
            dependencies: [
                .product(name: "TradingStrategy", package: "Strategy")
            ]
        ),
        .testTarget(
            name: "MyStrategyPackageTests",
            dependencies: ["MyStrategyPackage"]),
    ]
)
```

✔️ This setup ensures that your strategy package will generate a .dylib file that TradeUI can dynamically load.

⸻

Step 2: Implement Your Strategy

Inside your strategy package, implement your trading logic.
```swift
import Foundation
import TradingStrategy

public struct ORBStrategy: Strategy {
    public var charts: [[Klines]] = []
    public var resolution: [Scale] = []
    public var distribution: [[Phase]] = []
    public var indicators: [[String: [Double]]] = []
    public var levels: [Level] = []
    public var patternIdentified: Bool = false
    public var patternInformation: [String: Bool] = [:]

    public init(candles: [Klines]) {
        self.charts = [candles]
    }

    public func unitCount(entryBar: Klines, equity: Double, feePerUnit cost: Double) -> Int {
        return 10
    }

    public func adjustStopLoss(entryBar: Klines) -> Double? {
        return nil
    }

    public func shouldExit(entryBar: Klines) -> Bool {
        return false
    }
}
```

⸻

Step 3: Expose Strategies to TradeUI

To allow TradeUI to discover and load your strategy, you must provide C-compatible function exports:
```swift
import Foundation
import TradingStrategy

@_cdecl("getAvailableStrategies")
public func getAvailableStrategies() -> UnsafeMutablePointer<CChar> {
    let strategyList = ["ORB"].joined(separator: ",")
    return strdup(strategyList)!
}

@_cdecl("createStrategy")
public func createStrategy(strategyName: UnsafePointer<CChar>) -> UnsafeRawPointer? {
    let name = String(cString: strategyName)
    
    let factory: () -> Strategy = {
        switch name {
        case "ORB":
            return ORBStrategy(candles: [])
        default:
            return ORBStrategy(candles: [])
        }
    }

    let boxedFactory = Box(factory)
    return UnsafeRawPointer(Unmanaged.passRetained(boxedFactory).toOpaque())
}

// Helper class for memory management
class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}
```

⸻

Step 4: Compile and Add Your Strategy to TradeUI

1️⃣ Build your strategy package:
```
swift build -c release
```
2️⃣ Locate the .dylib file inside .build/release/
3️⃣ Copy it to TradeUI’s strategy directory:
```
cp .build/release/libMyStrategyPackage.dylib ~/Downloads/Strategies/
```
4️⃣ Restart TradeUI.

⸻

📌 Legal Disclaimer

⚠️ IMPORTANT NOTICE:
	•	TradeUI and its related repositories do not provide financial, investment, or trading advice.
	•	This software is provided as-is, without any warranty of any kind.
	•	You are solely responsible for any trading decisions or financial losses that may result from using this software.
	•	The maintainers and contributors of this repository are not liable for any damages, direct or indirect, arising from the use of TradeUI.
	•	Trading involves significant risk, and past performance does not guarantee future results.

By using this software, you acknowledge that you have read and understood this disclaimer and agree to use it at your own risk.

⸻

📌 Installation

To set up TradeUI, clone the repository and install dependencies:
```
$ git clone https://github.com/TradeWithIt/TradeUI.git
$ cd TradeUI
$ swift build
```
Running in CLI Mode
```
$ swift run TradeUI --cli
```

⸻

📌 Contribution

We welcome contributions! Please submit issues and pull requests to improve TradeUI.

⸻

📌 License

TradeUI is released under the MIT License.
Please see the LICENSE file for more details.

🚀 **Now you can create, compile, and add your own trading strategies to TradeUI!** 🔥📈
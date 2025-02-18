# TradeUI

![Swift](https://img.shields.io/badge/Swift-5.0-orange) ![Platforms](https://img.shields.io/badge/platforms-macOS%20|%20iOS%20|%20iPadOS%20|%20Linux%20|%20Windows-blue)

## Overview
TradeUI is a comprehensive Swift-based trading interface that integrates real-time market data, executes trades, and provides an intuitive user experience for managing trading activities. This project is structured into modular components, ensuring scalability, maintainability, and flexibility for traders and developers alike.

## Architecture
TradeUI is built around several key modules that interact seamlessly to provide a fully functional trading environment. The primary components include:

### 1. **Brokerage Module**
Responsible for handling market data retrieval, trade execution, and order management.

- **Market.swift** – Defines market-related structures and provides real-time price updates.
- **MarketData.swift** – Manages historical and live market data required for analysis.
- **MarketOrder.swift** – Facilitates order placement and execution.
- **MarketSearch.swift** – Allows searching for market instruments and assets.

### 2. **Runtime Module**
Handles the execution logic, monitoring active trades, and ensuring strategies are adhered to.

- **Watcher.swift** – Observes market conditions, monitors active trades, and executes orders based on defined strategies.

### 3. **Trade Interface Module**
Acts as the central controller, managing trade flow and UI integration.

- **TradeManager.swift** – Oversees trade execution, market interaction, and user-initiated actions.

### 4. **Strategy Module**
Defines the logic for automated and manual trading strategies.

- **Strategy.swift** – Defines the `Strategy` protocol for implementing trading logic.
- **Phase.swift** – Categorizes market trends into structured phases (e.g., uptrend, downtrend, sideways).
- **Klines.swift** – Represents candlestick data for technical analysis.
- **Scale.swift** – Manages time and price scaling for market analysis.

### 5. **ForexFactory Module**
Fetches and integrates economic events for fundamental analysis.

- **ForexFactory.swift** – Retrieves Forex Factory economic events, allowing strategies to adjust based on macroeconomic news.

### 6. **Headless Trading Instance**
TradeUI allows running a trading instance without the UI application, enabling execution from the terminal on any supported platform, including macOS, Linux, and Windows (where Swift is available with Foundation support).

- **CLI Mode** – Enables trading via command-line interfaces.
- **Cross-Platform Compatibility** – Can run on macOS, Linux, and Windows without requiring a graphical user interface.

### 7. **Trade Decision Engine**
Handles trade entries, risk management, profit-taking, and exits.

- **TradeDecisionEngine.swift** – Manages trade lifecycle decisions, from entry to exit.
- **RiskManager.swift** – Implements stop-loss and take-profit mechanisms.
- **PositionManager.swift** – Optimizes trade position sizing based on market conditions.

## Interaction Flow

```plaintext
 +-------------------+
 |   TradeUI        |
 | (User Interface) |
 +--------+---------+
          |
          v
 +-------------------+
 |   TradeManager   |
 | (Core Controller)|
 +----+--------+----+
      |        |
      v        v
 +----+---+ +--+----+   +--------------------+
 |Watcher | |Strategy|  | TradeDecisionEngine |
 |Runtime | | Module |  | (Entry & Risk Mgmt) |
 +--------+ +--------+  +---------+----------+
      |        |                  |
      v        v                  v
 +----+--+  +--+----+  +-------------------+
 |Brokerage|  |Forex |  |  PositionManager  |
 | Module  |  |Factory| |    (trade flow)   |
 +---------+  +------+  +-------------------+
```

### Execution Workflow:
1. **Market Data Retrieval** – The `Brokerage` module fetches market prices and order book data.
2. **Strategy Analysis** – The `Strategy` module evaluates market conditions and defines trade actions.
3. **Entry Decision** – The `TradeDecisionEngine` validates the signal and ensures risk-reward conditions are met.
4. **Trade Execution** – If conditions align, it places a trade via `MarketOrder.swift`.
5. **Risk & Position Management** – The `RiskManager` sets stop-loss and take-profit levels dynamically.
6. **Trade Optimization** – The `PositionManager` adjusts position size based on market conditions.
7. **Exit Strategy** – The system **monitors market conditions**, and `TradeDecisionEngine` determines the best exit point.

## Installation
To set up TradeUI, clone the repository and install dependencies:

```sh
$ git clone https://github.com/TradeWithIt/TradeUI.git
$ cd TradeUI
$ swift build
```

### Running in CLI Mode
For headless execution:
```sh
$ swift run TradeUI --cli
```

## Contribution
We welcome contributions! Please submit issues and pull requests to improve TradeUI.

## License
TradeUI is released under the MIT License. See `LICENSE` for details.


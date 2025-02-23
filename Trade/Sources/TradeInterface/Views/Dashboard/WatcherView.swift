import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    let watcher: Watcher?

    public init(watcher: Watcher?) {
        self.watcher = watcher
    }

    // Computed properties to get the latest values from `Quote`
    private var bidPrice: String {
        formatPrice(watcher?.quote?.bidPrice)
    }

    private var askPrice: String {
        formatPrice(watcher?.quote?.askPrice)
    }

    private var lastPrice: String {
        formatPrice(watcher?.quote?.lastPrice)
    }

    private var volume: String {
        formatPrice(watcher?.quote?.volume)
    }

    public var body: some View {
        if let watcher {
            StrategyChart(
                strategy: watcher.strategy,
                interval: watcher.interval,
                quoteView: {
                    HStack {
                        tickView(title: "LAST", value: lastPrice)
                        tickView(title: "BID", value: bidPrice)
                        tickView(title: "ASK", value: askPrice)
                        tickView(title: "Volume", value: volume)
                        Text("\(watcher.contract.symbol)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            )
            .id(watcher.id)
        } else {
            ChartView(interval: 60, data: [])
        }
    }

    // Helper function to format price safely
    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f", value)
    }

    private func tickView(title: String, value: String) -> some View {
        VStack {
            Text(title).font(.footnote)
            Text(value).font(.body)
        }
    }
}

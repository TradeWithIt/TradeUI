import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    @Environment(TradeManager.self) private var trades
    @State var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
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
    
    private func formattedTimeInterval(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "N/A" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    public var body: some View {
        if let watcher {
            StrategyChart(
                strategy: watcher.strategy,
                interval: watcher.interval,
                quoteView: {
                    HStack {
                        Spacer()
                        HStack {
                            tickView(title: "LAST", value: lastPrice)
                            tickView(title: "BID", value: bidPrice)
                            tickView(title: "ASK", value: askPrice)
                            tickView(title: "Volume", value: volume)
                        }
                        Spacer()
                        HStack {
                            Text(formattedTimeInterval(isMarketOpen.timeUntilChange))
                                .font(.subheadline)
                                .foregroundColor(isMarketOpen.isOpen ? .green : .red)
                            Text("\(watcher.contract.symbol)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                }
            )
            .id(watcher.id)
            .onReceive(timer) { _ in
                var change = isMarketOpen
                if let time = change.timeUntilChange {
                    change.timeUntilChange = max(0, time - 1)
                    if change.timeUntilChange == 0 {
                        watcher.fetchTredingHours(marketData: trades.market)
                    }
                }
                isMarketOpen = change
            }
            .onChange(of: watcher.tradingHours, initial: true) {
                isMarketOpen = watcher.tradingHours.isMarketOpen()
            }
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

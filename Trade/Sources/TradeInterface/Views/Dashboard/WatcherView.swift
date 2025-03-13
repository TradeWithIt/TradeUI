import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    @Environment(TradeManager.self) private var trades
    @State private var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    @State private var strategy: Strategy?
    @State private var interval: TimeInterval?

    let watcher: Watcher?
    let showActionButtons: Bool
    let showChart: Bool

    // Timer to fetch updates every second
    private let updateTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    public init(watcher: Watcher?, showChart: Bool = true, showActionButtons: Bool = false) {
        self.watcher = watcher
        self.showChart = showChart
        self.showActionButtons = showActionButtons
    }

    public var body: some View {
        if let watcher {
            VStack {
                HStack {
                    StrategyQuoteView(
                        watcher: watcher,
                        showActionButtons: showActionButtons
                    )
                    Spacer(minLength: 0)
                    if let strategy {
                        StrategyCheckList(strategy: strategy)
                    }
                }
                if showChart, let strategy, let interval {
                    StrategyChart(
                        strategy: strategy,
                        interval: interval
                    )
                    .id(watcher.id)
                }
            }
            .id(watcher.id + "_view")
            .onReceive(updateTimer) { _ in
                Task { await fetchWatcherState() }
            }
        }
    }

    // MARK: - Async Fetching
    
    private func fetchWatcherState() async {
        guard let watcher else { return }
        strategy = await watcher.watcherState.getStrategy()
        interval = watcher.interval
        isMarketOpen = watcher.tradingHours.isMarketOpen()
    }
}

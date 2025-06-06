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
    let showActions: Bool
    let showChart: Bool

    // Timer to fetch updates every second
    private let updateTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    public init(watcher: Watcher?, showChart: Bool = true, showActions: Bool = false) {
        self.watcher = watcher
        self.showChart = showChart
        self.showActions = showActions
    }

    public var body: some View {
        if let watcher {
            VStack {
                StrategyQuoteView(
                    watcher: watcher,
                    showActions: showActions
                )
                if let strategy {
                    StrategyCheckList(strategy: strategy)
                }
                if showChart, let strategy, let interval {
                    StrategyChart(
                        strategy: strategy,
                        interval: interval
                    )
                    .id(watcher.id)
                    .overlay(alignment: .bottomLeading) {
                        HStack {
                            Button("Pull") {
                                watcher.pullNext = true
                            }
                            
                            Button("Order") {
                                Task {
                                    await watcher.tradeAggregator.placeManualTrade(from: watcher, isLong: true)
                                }
                            }
                        }.padding()
                    }
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
        isMarketOpen = await watcher.watcherState.getTradingHours()?.isMarketOpen() ?? (false, nil)
    }
}

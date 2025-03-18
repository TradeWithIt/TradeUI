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
                GeometryReader { geometry in
                    HStack {
                        StrategyQuoteView(
                            watcher: watcher,
                            showActions: showActions
                        )
                        .frame(width: geometry.size.width * 5.0/7.0, height: geometry.size.height)
                        Group {
                            if let strategy {
                                StrategyCheckList(strategy: strategy)
                            } else {
                                Spacer()
                            }
                        }
                        .frame(width: geometry.size.width * 2.0/7.0, height: geometry.size.height)
                    }
                }
                .frame(height: 32)
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
        isMarketOpen = await watcher.watcherState.getTradingHours()?.isMarketOpen() ?? (false, nil)
    }
}

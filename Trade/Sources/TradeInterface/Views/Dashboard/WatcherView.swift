import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    @Environment(TradeManager.self) private var trades
    @State var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let watcher: Watcher?
    let showActionButtons: Bool
    let showChart: Bool

    public init(watcher: Watcher?, showChart: Bool = true, showActionButtons: Bool = false) {
        self.watcher = watcher
        self.showChart = showChart
        self.showActionButtons = showActionButtons
    }

    public var body: some View {
        if let watcher {
            VStack {
                HStack {
                    StrategyQuoteView(watcher: watcher, showActionButtons: showActionButtons)
                    Spacer()
                    StrategyCheckList(strategy: watcher.strategy)
                }
                if showChart {
                    StrategyChart(
                        strategy: watcher.strategy,
                        interval: watcher.interval
                    )
                    .id(watcher.id)
                }
            }
            .id(watcher.id + "_view")
        }
    }
}

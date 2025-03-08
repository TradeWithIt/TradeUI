import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    @Environment(TradeManager.self) private var trades
    @State var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    @Binding var watcher: Watcher?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let showActionButtons: Bool
    let showChart: Bool

    public init(watcher: Binding<Watcher?>, showChart: Bool = true, showActionButtons: Bool = false) {
        self._watcher = watcher
        self.showChart = showChart
        self.showActionButtons = showActionButtons
    }

    public var body: some View {
        if let watcher {
            VStack {
                HStack {
                    StrategyQuoteView(
                        watcher: .constant(watcher),
                        showActionButtons: showActionButtons
                    )
                    Spacer(minLength: 0)
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

import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct WatcherView: View {
    @State var bidPrice: String = "-"
    @State var askPrice: String = "-"
    @State var lastPrice: String = "-"
    @State var volume: String = "-"
    
    let watcher: Watcher?
    
    public init(watcher: Watcher?) {
        self.watcher = watcher
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
                    }
                }
            )
            .id(watcher.id)
            .onChange(of: watcher.quote) {
                guard let type = watcher.quote?.type else { return }
                switch type {
                case .lastPrice: lastPrice = String(format: "%.2f", watcher.quote?.value ?? 0)
                case .bidPrice: bidPrice = String(format: "%.2f", watcher.quote?.value ?? 0)
                case .askPrice: askPrice = String(format: "%.2f", watcher.quote?.value ?? 0)
                case .volume: volume = String(format: "%.2f", watcher.quote?.value ?? 0)
                }
                
            }
        } else {
            ChartView(interval: 60, data: [])
        }
    }
    
    private func tickView(title: String, value: String) -> some View {
        VStack {
            Text(title).font(.footnote)
            Text(value).font(.body)
        }
    }
}

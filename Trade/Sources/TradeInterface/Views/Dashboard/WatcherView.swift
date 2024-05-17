import SwiftUI
import Runtime
import TradingStrategy

struct WatcherView: View {
    let watcher: Watcher?
    
    var body: some View {
        if let watcher {
            StrategyChart(
                strategy: watcher.strategy,
                interval: watcher.interval
            )
            .id(watcher.id)
        } else {
            ChartView(interval: 60, data: [])
        }
    }
}

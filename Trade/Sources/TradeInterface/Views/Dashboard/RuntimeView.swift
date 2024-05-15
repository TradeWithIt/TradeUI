import SwiftUI
import TradingStrategy
import TradeWithIt

struct RuntimeView: View {
    let runtime: Runtime?
    
    var body: some View {
        StrategyChart(
            strategy: SupriseBarStrategy(candles: runtime?.candles ?? []),
            interval: runtime?.interval ?? 60
        )
    }
}

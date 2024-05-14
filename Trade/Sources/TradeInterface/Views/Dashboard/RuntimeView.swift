import SwiftUI
import TradingStrategy

struct RuntimeView: View {
    let runtime: Runtime?
    
    var body: some View {
        SupriseBarChart(runtime: runtime ?? Runtime(symbol: "Unknown", interval: 60))
    }
}

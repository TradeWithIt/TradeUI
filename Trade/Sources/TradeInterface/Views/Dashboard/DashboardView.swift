import SwiftUI

/*
 https://www.tradovate.com/resources/markets/margin/
 */

struct DashboardView: View {
    @Environment(TradeManager.self) private var trades
    @State private var viewModel = ViewModel()
    
    var body: some View {
        NavigationSplitView(
            sidebar: { sidebar },
            detail: { detail }
        )
        .searchSuggestions {
            ForEach(viewModel.suggestedSearches, id: \.id) { suggestion in
                suggestionView(label: suggestion, symbol: suggestion)
            }
            Divider()
            suggestionView(label: "S&P 500 1min", symbol: "MESM4", interval: 60)
            
            suggestionView(label: "S&P 500 15min", symbol: "MESM4", interval: 900)
        }
        .searchable(text: $viewModel.symbol)
        .onChange(of: viewModel.symbol) {
            viewModel.suggestSearches()
        }
        .onChange(of: trades.watchers.isEmpty) {
            guard trades.selectedWatcher == nil else { return }
            trades.selectedWatcher = trades.watchers.first?.value.id
        }
    }
    
    func suggestionView(
        label: String,
        symbol: String,
        interval: TimeInterval = 60
    ) -> some View {
        SuggestionView(label: label, symbol: symbol) {
            marketData(symbol, interval: interval)
        }
    }
    
    var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                ForEach(Array(trades.watchers.values.sorted(by: { $0.id < $1.id })), id: \.id) { watcher in
                    Text("\(watcher.symbol): \(viewModel.formatCandleTimeInterval(watcher.interval))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .bold(trades.selectedWatcher == watcher.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            trades.selectedWatcher = watcher.id
                        }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var detail: some View {
        HStack {
            charts
//            controlPanel
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        WatcherView(watcher: trades.watcher)
    }
    
    var controlPanel: some View {
        OrderView(watcher: trades.watcher)
    }
    
    
    private func marketData(_ symbol: String, interval: TimeInterval) {
        do {
            try trades.marketData(symbol, interval: interval)
        } catch {
            print("🔴 Faile to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

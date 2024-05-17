import SwiftUI
import SwiftUIComponents

struct DashboardView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
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
            suggestionView(label: "Micro E-Mini S&P 500 (1 min)", symbol: "MESM4", interval: 60)
            suggestionView(label: "E-Mini S&P 500 (1 min)", symbol: "ESM4", interval: 60)

            suggestionView(label: "Micro E-mini Russell 2000 (1 min)", symbol: "M2KM4", interval: 60)
            suggestionView(label: "E-Mini Russell 2000 (1 min)", symbol: "RTYM4", interval: 60)
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
                    HStack {
                        Text("\(watcher.symbol): \(viewModel.formatCandleTimeInterval(watcher.interval))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .bold(trades.selectedWatcher == watcher.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                trades.selectedWatcher = watcher.id
                            }
                        Spacer(minLength: 0)
                        Button(action: {
                            cancelMarketData(watcher.symbol, interval: watcher.interval)
                        }, label: {
                            Image(systemName: "xmark")
                                .resizable()
                        })
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                watchedAssets.forEach {
                    self.marketData($0.symbol, interval: $0.interval)
                }
            }
        }
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
    
    
    private func cancelMarketData(_ symbol: String, interval: TimeInterval) {
        let asset = Asset(symbol: symbol, interval: interval)
        watchedAssets.remove(asset)
        trades.cancelMarketData(asset)
    }
    
    private func marketData(_ symbol: String, interval: TimeInterval) {
        do {
            let asset = Asset(symbol: symbol, interval: interval)
            watchedAssets.insert(asset)
            try trades.marketData(asset)
        } catch {
            print("🔴 Faile to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

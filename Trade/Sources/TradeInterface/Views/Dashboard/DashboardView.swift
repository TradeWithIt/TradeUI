import SwiftUI
import SwiftUIComponents
import Brokerage
import Runtime

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
            ForEach(viewModel.suggestedSearches, id: \.hashValue) { suggestion in
                suggestionView(
                    contract: Instrument(
                        type: suggestion.type,
                        symbol: suggestion.symbol,
                        exchangeId: suggestion.exchangeId,
                        currency: suggestion.currency
                    ),
                    interval: 300
                )
            }
            Divider()
            suggestionView(contract: Instrument.APPL, interval: 300)
            suggestionView(contract: Instrument.BTC, interval: 300)
            suggestionView(contract: Instrument.ETH, interval: 300)
        }
        .searchable(text: $viewModel.symbol.value)
        .onChange(of: trades.watchers.isEmpty) {
            guard trades.selectedWatcher == nil else { return }
            trades.selectedWatcher = trades.watchers.first?.value.id
        }
        .task {
            Task {
                viewModel.updateMarketData(trades.market)
            }
        }
    }
    
    func suggestionView(
        contract: any Contract,
        interval: TimeInterval = 300
    ) -> some View {
        SuggestionView(label: contract.label, symbol: contract.symbol) {
            marketData(contract: contract, interval: interval)
        }
    }
    
    var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                Divider()
                activeAssets
                Divider()
                FileSnapshotsView()
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                watchedAssets.forEach {
                    self.marketData(contract: $0.instrument, interval: $0.interval)
                }
            }
        }
    }
    
    var activeAssets: some View {
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
                activeAssetsButtons(watcher: watcher)
            }
        }
    }
    
    func activeAssetsButtons(watcher: Watcher) -> some View {
        HStack {
            Button(action: {
                watcher.saveCandles(fileProvider: trades.fileProvider)
            }, label: {
                Image(systemName: "arrow.down.circle")
                    .resizable()
            })
            .buttonStyle(PlainButtonStyle())
            .frame(width: 12, height: 12)
            
            Button(action: {
                cancelMarketData(watcher.contract, interval: watcher.interval)
            }, label: {
                Image(systemName: "xmark.circle")
                    .resizable()
            })
            .buttonStyle(PlainButtonStyle())
            .frame(width: 12, height: 12)
        }
    }
    
    var detail: some View {
        VStack {
            charts
            controlPanel
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        WatcherView(watcher: trades.watcher)
    }
    
    var controlPanel: some View {
        OrderView(watcher: trades.watcher)
    }
    
    private func cancelMarketData(_ contract: any Contract, interval: TimeInterval) {
        let asset = Asset(
            instrument: Instrument(
                type: contract.type,
                symbol: contract.symbol,
                exchangeId: contract.exchangeId,
                currency: contract.currency
            ),
            interval: interval
        )
        watchedAssets.remove(asset)
        trades.cancelMarketData(asset)
    }
    
    private func marketData(contract: any Contract, interval: TimeInterval) {
        do {
            let asset = Asset(
                instrument: Instrument(
                    type: contract.type,
                    symbol: contract.symbol,
                    exchangeId: contract.exchangeId,
                    currency: contract.currency
                ),
                interval: interval
            )
            watchedAssets.insert(asset)
            try trades.marketData(contract: contract, interval: interval)
        } catch {
            print("🔴 Failed to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

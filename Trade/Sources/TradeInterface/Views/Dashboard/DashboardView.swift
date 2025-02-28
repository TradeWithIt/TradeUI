import SwiftUI
import SwiftUIComponents
import Brokerage
import Runtime

struct DashboardView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
    @Environment(TradeManager.self) private var trades
    
    @State private var viewModel = ViewModel()
    @State private var account: Account?
    @State private var showTradeList = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationSplitView(
            sidebar: { sidebar },
            detail: { detail }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showTradeList.toggle() }) {
                    Label("Trade History", systemImage: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $showTradeList) {
            TradeListView()
                .frame(minWidth: 400, minHeight: 300)
        }
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
            suggestionView(contract: Instrument.MESM4, interval: 300)
            suggestionView(contract: Instrument.M2KM4, interval: 300)
        }
        .searchable(text: $viewModel.symbol.value)
        .onReceive(timer) { _ in
            account = trades.market.account
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
        VStack {
            TabView(selection: $viewModel.selectedTab) {
                VStack {
                    if let account {
                        AccountSummaryView(account: account)
                    }
                    Spacer()
                    if let _ = trades.watcher {
                        OrderView(account: account, watcher: trades.watcher).padding()
                    }
                }
                .tag(ViewModel.SidebarTab.watchers)
                .tabItem { Label("Account", systemImage: "chart.bar.fill") }
                
                FileSnapshotsView()
                    .tag(ViewModel.SidebarTab.localFiles)
                    .tabItem { Label("Local Files", systemImage: "folder.fill") }
            }
            
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
    
    var detail: some View {
        VStack(alignment: .leading) {
            Text("Watchers").font(.title2).padding()
            Divider()
            charts
            
            Text("Portfolio").font(.title2).padding()
            Divider()
            OrderView(account: account, watcher: trades.watcher, show: .portfolio)
            
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        VStack {
            ForEach(Array(trades.watchers.values), id: \.id) { watcher in
                WatcherView(watcher: watcher, showChart: false, showActionButtons: true)
                Divider()
            }
        }
        .padding([.horizontal, .bottom])
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

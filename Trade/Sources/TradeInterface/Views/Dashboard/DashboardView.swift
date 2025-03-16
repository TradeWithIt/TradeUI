import SwiftUI
import SwiftUIComponents
import Brokerage
import Runtime

struct DashboardView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
    @CodableAppStorage("selected.strategy.same") private var selectedStrategyName: String = "ORB"
    @Environment(TradeManager.self) private var trades
    @EnvironmentObject var strategyRegistry: StrategyRegistry
    
    @State private var viewModel = ViewModel()
    @State private var account: Account?
    @State private var showTradeList = false
    @State private var showIntervalPicker = false
    @State private var interval: TimeInterval = 300
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var selectedStrategyBinding: Binding<String> {
        Binding(
            get: { selectedStrategyName },
            set: { value, transaction in
                selectedStrategyName = value
        })
    }
    
    var body: some View {
        NavigationSplitView(
            sidebar: { sidebar },
            detail: { detail }
        )
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showTradeList.toggle() }) {
                    Label("Trade History", systemImage: "externaldrive")
                }
                StrategyPicker(selectedStrategyName: selectedStrategyBinding)
                Button(action: { showIntervalPicker.toggle() }) {
                    IntervalLabelView(interval: interval)
                }
            }
        }
        .sheet(isPresented: $showTradeList) {
            TradeListView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .popover(isPresented: $showIntervalPicker) {
            IntervalPickerView(interval: $interval)
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
                    interval: interval
                )
            }
            Divider()
            suggestionView(contract: Instrument.RTY, interval: interval)
            suggestionView(contract: Instrument.NQ, interval: interval)
            suggestionView(contract: Instrument.MES, interval: interval)
            suggestionView(contract: Instrument.M2K, interval: interval)
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
    
    func suggestionView(contract: any Contract, interval: TimeInterval) -> some View {
        SuggestionView(label: contract.label, symbol: contract.symbol) {
            marketData(contract: contract, interval: interval, strategyName: selectedStrategyName)
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
                        OrderView(watcher: trades.watcher, account: account).padding()
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
                    self.marketData(contract: $0.instrument, interval: $0.interval, strategyName: $0.strategyName)
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
            OrderView(watcher: trades.watcher, account: account, show: .portfolio)
            
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        VStack(alignment: .leading) {
            ForEach(Array(trades.watchersGroups()), id: \.key) { aggregator, watchers in
                Section(header: Text("Trade Aggregator: \(aggregator.id)")
                    .font(.headline)
                    .padding(.leading)
                    .foregroundColor(.blue)
                ) {
                    ForEach(watchers, id: \.id) { watcher in
                        WatcherView(watcher: watcher, showChart: false, showActions: true)
                            .border(watcher.contract.label == aggregator.contract.label ? Color.yellow : Color.clear, width: 1)
                            .contentShape(Rectangle())
                            .onDrag {
                                NSItemProvider(object: watcher.id as NSString)
                            }
                            .onDrop(of: [.text], isTargeted: nil) { providers in
                                handleDrop(providers: providers, targetWatcher: watcher)
                            }
                        Divider()
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .padding([.horizontal, .bottom])
    }
    
    private func handleDrop(providers: [NSItemProvider], targetWatcher: Watcher) -> Bool {
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { (id, error) in
                guard let idString = id as? String else { return }
                
                DispatchQueue.main.async {
                    if let draggedWatcher = trades.watchers[idString] {
                        draggedWatcher.tradeAggregator = targetWatcher.tradeAggregator
                        strategyRegistry.objectWillChange.send()
                    }
                }
            }
            return true
        }
    
    private func marketData(contract: any Contract, interval: TimeInterval, strategyName: String) {
        do {
            guard let steategyType = strategyRegistry.strategy(forName: strategyName) else {
                print("🔴 Failed to find strategy \(selectedStrategyName)")
                return
            }
            let asset = Asset(
                instrument: Instrument(
                    type: contract.type,
                    symbol: contract.symbol,
                    exchangeId: contract.exchangeId,
                    currency: contract.currency
                ),
                interval: interval,
                strategyName: strategyName
            )
            watchedAssets.insert(asset)
            try trades.marketData(contract: contract, interval: interval, strategyType: steategyType)
        } catch {
            print("🔴 Failed to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

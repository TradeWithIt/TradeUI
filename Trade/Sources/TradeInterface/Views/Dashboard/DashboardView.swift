import SwiftUI
import SwiftUIComponents
import TradingStrategy
import Brokerage
import Runtime

struct DashboardView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
    @AppStorage("selected.strategy.same") private var selectedStrategyName: String = "Viewing only"
    @AppStorage("trade.alert.sound") private var alertSoundEnabled: Bool = true
    @AppStorage("trade.alert.message") private var alertMessageEnabled: Bool = true
    @AppStorage("selected.interval") private var interval: TimeInterval = 60
    @Environment(TradeManager.self) private var trades
    @EnvironmentObject var strategyRegistry: StrategyRegistry
    
    @State private var viewModel = ViewModel()
    @State private var account: Account?
    @State private var showTradeList = false
    @State private var showIntervalPicker = false
    
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
                Checkbox(label: "Sound", checked: alertSoundEnabled)
                    .fixedSize()
                    .contentShape(Rectangle())
                    .onTapGesture { alertSoundEnabled = !alertSoundEnabled }
                Checkbox(label: "Message", checked: alertMessageEnabled)
                    .fixedSize()
                    .contentShape(Rectangle())
                    .onTapGesture { alertMessageEnabled = !alertMessageEnabled }
                Button(action: {
                    Task {
                        guard viewModel.chooseStrategyFolder(registry: strategyRegistry) else { return }
                        trades.loadAllUserStrategies(into: strategyRegistry)
                    }
                }) {
                    Label("Strategies", systemImage: "externaldrive")
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
            suggestionView(contract: Instrument.APPL, interval: interval)
            suggestionView(contract: Instrument.NQ, interval: interval)
            suggestionView(contract: Instrument.ES, interval: interval)
        }
        .searchable(text: $viewModel.symbol.value)
        .onReceive(timer) { _ in
            account = trades.market.account
        }
        .task {
            let events = await viewModel.loadForexEvents()
            trades.updateAnnoucments(events)
        }
        .task {
            viewModel.updateMarketData(trades.market)
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
            VStack(alignment: .leading) {
                HStack {
                    Text("Watchers").font(.title2).padding(.leading)
                    Spacer()
                    Button(
                        action: {
                            trades.removeAllWatchers()
                            Task {
                                await MainActor.run {
                                    watchedAssets.removeAll()
                                }
                            }
                        },
                        label: { Text("Remove All") }
                    )
                }
                .padding(.trailing)
                charts
            }.frame(maxHeight: .infinity)
            
            TabView {
                if account?.orders.values.isEmpty == false || account?.positions.isEmpty == false {
                    VStack(alignment: .leading) {
                        Text("Portfolio").font(.title2).padding(.leading)
                        OrderView(watcher: trades.watcher, account: account, show: .portfolio)
                    }
                    .tabItem {
                        Label("Orders", systemImage: "cart.fill")
                    }
                }
                
                EventsView(events: viewModel.events)
                    .tabItem {
                        Label("Events", systemImage: "calendar")
                    }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                ForEach(Array(trades.watchersGroups()), id: \.key) { aggregator, watchers in
                    aggregatorSection(aggregator, watchers: watchers)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .scrollContentBackground(.hidden)
        .frame(maxHeight: .infinity)
        .padding()
    }
    
    func aggregatorSection(_ aggregator: TradeAggregator, watchers: [Watcher]) -> some View {
        Section(
            header: aggregatorSectionHeader(aggregator, watchers: watchers),
            content:  {
                ForEach(watchers, id: \.id) { watcher in
                    WatcherView(watcher: watcher, showChart: false, showActions: true)
                        .if(watchers.count > 1 && watcher.contract.label == aggregator.contract.label) { view in
                            view.badge(label: "⚡︎", color: .blue.opacity(0.6), alignment: .topLeading)
                        }
                        .contentShape(Rectangle())
                        .onDrag {
                            NSItemProvider(object: watcher.id as NSString)
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, targetWatcher: watcher)
                        }
                }
            })
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    func aggregatorSectionHeader(_ aggregator: TradeAggregator, watchers: [Watcher]) -> some View {
        if watchers.count > 1 {
            HStack {
                Text("Will Trade: \(aggregator.contract.label)")
                    .font(.headline)
                    .foregroundColor(.blue)
                Divider()
                aggregatorSettings(aggregator)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom)
        } else {
            VStack {
                Divider()
                aggregatorSettings(aggregator)
            }
        }
    }
    
    func aggregatorSettings(_ aggregator: TradeAggregator) -> some View {
        HStack {
            Checkbox(label: "Auto Entry", checked: aggregator.isTradeEntryEnabled)
                .onTapGesture {
                    aggregator.isTradeEntryEnabled.toggle()
                    trades.selectedWatcher = UUID().uuidString
                }
            Divider()
            Checkbox(label: "Auto Exit", checked: aggregator.isTradeExitEnabled)
                .onTapGesture {
                    aggregator.isTradeExitEnabled.toggle()
                    trades.selectedWatcher = UUID().uuidString
                }
            Divider()
            Checkbox(label: "Entry Alert", checked: aggregator.isTradeEntryNotificationEnabled)
                .onTapGesture {
                    aggregator.isTradeEntryNotificationEnabled.toggle()
                    trades.selectedWatcher = UUID().uuidString
                }
            Divider()
            Checkbox(label: "Exit Alert", checked: aggregator.isTradeExitNotificationEnabled)
                .onTapGesture {
                    aggregator.isTradeExitNotificationEnabled.toggle()
                    trades.selectedWatcher = UUID().uuidString
                }
            Spacer(minLength: 0)
        }
        .foregroundColor(.gray)
        .frame(height: 12)
    }
    
    private func handleDrop(providers: [NSItemProvider], targetWatcher: Watcher) -> Bool {
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { (id, error) in
                guard let idString = id as? String else { return }
                
                DispatchQueue.main.async {
                    if let draggedWatcher = trades.watchers[idString] {
                        draggedWatcher.tradeAggregator = targetWatcher.tradeAggregator
                        targetWatcher.tradeAggregator.minConfirmations += 1
                        strategyRegistry.objectWillChange.send()
                    }
                }
            }
            return true
        }
    
    private func marketData(contract: any Contract, interval: TimeInterval, strategyName: String) {
        do {
            let steategyType: Strategy.Type = strategyRegistry.strategy(forName: strategyName) ?? DoNothingStrategy.self
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
            try trades.marketData(
                contract: contract,
                interval: interval,
                strategyName: strategyName,
                strategyType: steategyType
            )
        } catch {
            print("🔴 Failed to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

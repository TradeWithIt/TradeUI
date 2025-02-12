import SwiftUI
import SwiftUIComponents
import Brokerage

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
                suggestionView(label: suggestion.label, symbol: suggestion.localSymbol)
            }
            Divider()
            
            suggestionView(label: "Micro E-Mini S&P 500 (1 min)", symbol: "MESM4", interval: 300)
            suggestionView(label: "E-Mini S&P 500 (1 min)", symbol: "ESM4", interval: 300)

            suggestionView(label: "Micro E-mini Russell 2000 (1 min)", symbol: "M2KM4", interval: 300)
            suggestionView(label: "E-Mini Russell 2000 (1 min)", symbol: "RTYM4", interval: 300)
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
            Task {
                viewModel.loadSnapshotFileNames(url: trades.fileProvider.snapshotsDirectory)
            }
        }
    }
    
    func suggestionView(
        label: String,
        symbol: String,
        interval: TimeInterval = 300
    ) -> some View {
        SuggestionView(label: label, symbol: symbol) {
            marketData(symbol, interval: interval)
        }
    }
    
    func suggestionView(
        contract: any Contract,
        interval: TimeInterval = 300
    ) -> some View {
        SuggestionView(label: contract.label, symbol: contract.localSymbol) {
            marketData(contract: contract, interval: interval)
        }
    }
    
    var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                Divider()
                Button("Load data") {
                    do {
                        try viewModel.saveHistoryToFile(
                            symbol: "BTC",
                            type: "CRYPTO",
                            interval: 300,
                            fileProvider: trades.fileProvider
                        )
                    } catch {
                        print("Failed saving hisotry to file", error)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
                Divider()
                activeAssets
                Divider()
                fileSnapshots
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
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.isPresentingSgeet != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.isPresentingSgeet = nil
                }
            }
        )) {
            switch viewModel.isPresentingSgeet {
            case .snapshotPreview:
                SnapshotView(fileName: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
            case .snapshotPlayback:
                SnapshotPlaybackView(fileName: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
            default:
                EmptyView()
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
    
    var fileSnapshots: some View {
        ForEach(viewModel.snapshotFileNames, id: \.self) { fileName in
            VStack {
                Text(fileName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack {
                    Button(action: {
                        viewModel.selectedSnapshot = fileName
                        viewModel.isPresentingSgeet = .snapshotPreview
                    }) {
                        Image(systemName: "eye.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        viewModel.selectedSnapshot = fileName
                        viewModel.isPresentingSgeet = .snapshotPlayback
                    }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                }.padding(.top, 4)
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
            print("🔴 Failed to subscribe IB market data with error:", error)
        }
    }
    
    private func marketData(contract: any Contract, interval: TimeInterval) {
        do {
            let asset = Asset(symbol: contract.localSymbol, interval: interval)
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

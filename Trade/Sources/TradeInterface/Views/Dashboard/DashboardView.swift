import SwiftUI

/*
 https://www.tradovate.com/resources/markets/margin/
 */

struct DashboardView: View {
    @CodableAppStorage("chartSubscriptions") private var chartSubscriptions: Set<Chart> = []
    @Environment(TradeManager.self) private var trades
    @State private var viewModel = ViewModel()
    
    var body: some View {
        NavigationSplitView(
            sidebar: { sidebar },
            detail: { detail }
        )
        .searchSuggestions {
            ForEach(viewModel.suggestedSearches, id: \.contractID) { suggestion in
                suggestionView(label: suggestion.symbol, symbol: suggestion.symbol)
            }
            Divider()
            suggestionView(label: "S&P 500", contract: .microSPX, interval: 60)
            suggestionView(label: "DAX", contract: .dax, interval: 60)
            
            suggestionView(label: "ETH:1m", symbol: "ETH", interval: 60, secType: "CRYPTO", exchange: "PAXOS")
            suggestionView(label: "ETH:3m", symbol: "ETH", interval: 180, secType: "CRYPTO", exchange: "PAXOS")
            suggestionView(label: "ETH:5m", symbol: "ETH", interval: 300, secType: "CRYPTO", exchange: "PAXOS")
            
        }
        .searchable(text: $viewModel.symbol)
        .onChange(of: viewModel.symbol) {
            viewModel.suggestSearches()
        }
        .onChange(of: trades.runtimes.isEmpty) {
            guard trades.selectedRuntime == nil else { return }
            trades.selectedRuntime = trades.runtimes.first?.value.id
        }
    }
    
    func suggestionView(
        label: String,
        symbol: String,
        interval: TimeInterval = 60,
        secType: String = "FUT",
        exchange: String = "CME"
    ) -> some View {
        SuggestionView(label: label, symbol: symbol) {
            marketData(symbol, interval: interval, secType: secType, exchange: exchange)
        }
    }
    
    func suggestionView(
        label: String,
        contract: Contract,
        interval: TimeInterval = 60
    ) -> some View {
        SuggestionView(label: label, symbol: contract.symbol) {
            marketData(contract, interval: interval)
        }
    }
    
    var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                ForEach(Array(trades.runtimes.values.sorted(by: { $0.id < $1.id })), id: \.id) { runtime in
                    Text("\(runtime.symbol): \(viewModel.formatCandleTimeInterval(runtime.interval))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .bold(trades.selectedRuntime == runtime.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            trades.selectedRuntime = runtime.id
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
            controlPanel
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    var charts: some View {
        RuntimeView(runtime: trades.runtime)
    }
    
    var controlPanel: some View {
        OrderView(runtime: trades.runtime)
    }
    
    
    private func marketData(_ contract: Contract, interval: TimeInterval) {
        do {
            guard let chart = try trades.marketData(contract, interval: interval) else { return }
            chartSubscriptions.insert(chart)
        } catch {
            print("🔴 Faile to subscribe IB market data with error:", error)
        }
    }
    
    private func marketData(
        _ symbol: String,
        interval: TimeInterval = 60,
        secType: String,
        exchange: String
    ) {
        do {
            guard let chart = try trades.marketData(
                symbol,
                interval: interval,
                secType: secType,
                exchange: exchange
            ) else { return }
            chartSubscriptions.insert(chart)
        } catch {
            print("🔴 Faile to subscribe IB market data with error:", error)
        }
    }
}

#Preview {
    DashboardView()
}

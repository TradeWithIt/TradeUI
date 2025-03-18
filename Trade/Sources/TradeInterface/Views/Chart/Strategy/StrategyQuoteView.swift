import SwiftUI
import SwiftUIComponents
import Runtime
import Brokerage
import TradingStrategy

public struct StrategyQuoteView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
    @Environment(TradeManager.self) private var trades
    @EnvironmentObject var strategyRegistry: StrategyRegistry
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    
    @State private var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    @State private var quote: Quote?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let showActions: Bool
    let watcher: Watcher
    
    public init(watcher: Watcher, showActions: Bool = false) {
        self.watcher = watcher
        self.showActions = showActions
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if showActions {
                activeAssetsButtons(watcher: watcher)
            }
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Text(strategyRegistry.strategyName(for: watcher.strategyType) ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(width: proxy.size.width / 7.0)
                    
                    Text("\(watcher.contract.symbol):\(watcher.interval.intervalString)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(width: proxy.size.width / 7.0)
                    
                    tickView(
                        title: isMarketOpen.isOpen ? "Open for" : "Closed for",
                        value: formattedTimeInterval(isMarketOpen.timeUntilChange)
                    )
                    .foregroundColor(isMarketOpen.isOpen ? .green : .red)
                    .frame(width: proxy.size.width / 7.0)
                    
                    tickView(title: "LAST", value: formatPrice(quote?.lastPrice))
                        .frame(width: proxy.size.width / 7.0)
                    tickView(title: "BID", value: formatPrice(quote?.bidPrice))
                        .frame(width: proxy.size.width / 7.0)
                    tickView(title: "ASK", value: formatPrice(quote?.askPrice))
                        .frame(width: proxy.size.width / 7.0)
                    tickView(title: "Volume", value: formatPrice(quote?.volume))
                        .frame(width: proxy.size.width / 7.0)
                }
                .frame(height: proxy.size.height)
            }
            .frame(height: 32)
        }
        .padding(.horizontal)
        .task { await fetchQuote() }
        .onReceive(timer) { _ in
            Task { await updateMarketOpenState() }
        }
    }
    
    // MARK: - Async Data Fetching
    
    private func fetchQuote() async {
        self.quote = await watcher.watcherState.getQuote()
    }
    
    private func updateMarketOpenState() async {
        self.isMarketOpen = await watcher.watcherState.getTradingHours()?.isMarketOpen() ?? (false, nil)
    }
    
    // MARK: - Views
    
    func activeAssetsButtons(watcher: Watcher) -> some View {
        HStack {
            Button(action: { trades.selectedWatcher = trades.selectedWatcher != watcher.id ? watcher.id : nil}) {
                Image(systemName: trades.selectedWatcher == watcher.id ? "checkmark.circle.fill" : "checkmark.circle")
                    .aspectRatio(1, contentMode: .fit)
            }
            #if os(macOS)
            Button(action: { openWindow(value: watcher.id) }) {
                Image(systemName: "chart.bar")
                    .aspectRatio(1, contentMode: .fit)
            }
            #endif
            Button(action: { watcher.saveCandles(fileProvider: trades.fileProvider) }) {
                Image(systemName: "square.and.arrow.down")
                    .aspectRatio(1, contentMode: .fit)
            }
            
            Button(
                action: {
                    Task {
                        guard let strategyName = strategyRegistry.strategyName(for: watcher.strategyType) else { return }
                        await cancelMarketData(watcher.contract, interval: watcher.interval, strategyName: strategyName)
                    }
                },
                label: {
                    Image(systemName: "xmark")
                        .aspectRatio(1, contentMode: .fit)
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func tickView(title: String, value: String) -> some View {
        VStack {
            Text(title)
                .font(.footnote)
            Text(value)
                .font(.body)
                .monospacedDigit()
        }
    }
    
    private func cancelMarketData(_ contract: any Contract, interval: TimeInterval, strategyName: String) async {
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
        await MainActor.run {
            var assetsToUpdate = watchedAssets
            if let removed = assetsToUpdate.remove(asset) {
                print("🟤 Removed watched asset:", removed, watchedAssets.count, assetsToUpdate.count)
            }
            watchedAssets = assetsToUpdate
        }
        trades.cancelMarketData(asset)
    }
    
    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "----.--" }
        return String(format: "%.2f", value)
    }
    
    private func formattedTimeInterval(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "00:00:00" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

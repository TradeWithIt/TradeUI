import SwiftUI
import SwiftUIComponents
import Runtime
import Brokerage
import TradingStrategy

public struct StrategyQuoteView: View {
    @CodableAppStorage("watched.assets") private var watchedAssets: Set<Asset> = []
    @Environment(TradeManager.self) private var trades
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @Binding var watcher: Watcher
    @State private var isMarketOpen: (isOpen: Bool, timeUntilChange: TimeInterval?) = (false, nil)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let showActionButtons: Bool
    
    // Computed properties to get the latest values from `Quote`
    private var bidPrice: String {
        formatPrice(watcher.quote?.bidPrice)
    }

    private var askPrice: String {
        formatPrice(watcher.quote?.askPrice)
    }

    private var lastPrice: String {
        formatPrice(watcher.quote?.lastPrice)
    }

    private var volume: String {
        formatPrice(watcher.quote?.volume)
    }
    
    private func formattedTimeInterval(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "00:00:00" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if showActionButtons {
                activeAssetsButtons(watcher: watcher)
            }
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Text("\(watcher.contract.symbol):\(watcher.interval.intervalString)")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: proxy.size.width / 6.0)
                    
                    tickView(
                        title: isMarketOpen.isOpen ? "Open for" : "Closed for",
                        value: formattedTimeInterval(isMarketOpen.timeUntilChange)
                    )
                    .foregroundColor(isMarketOpen.isOpen ? .green : .red)
                    .frame(width: proxy.size.width / 6.0)
                    
                    tickView(title: "LAST", value: lastPrice)
                        .frame(width: proxy.size.width / 6.0)
                    tickView(title: "BID", value: bidPrice)
                        .frame(width: proxy.size.width / 6.0)
                    tickView(title: "ASK", value: askPrice)
                        .frame(width: proxy.size.width / 6.0)
                    tickView(title: "Volume", value: volume)
                        .frame(width: proxy.size.width / 6.0)
                }
                .frame(height: proxy.size.height)
            }
            .frame(height: 32)
        }
        .padding(.horizontal)
        .onReceive(timer) { _ in
            var change = isMarketOpen
            if let time = change.timeUntilChange {
                change.timeUntilChange = time - 1
                if Int(time) == 0 {
                    watcher.fetchTredingHours(marketData: trades.market)
                    isMarketOpen = watcher.tradingHours.isMarketOpen()
                    return
                } else if Int(time) < 0 {
                    isMarketOpen = watcher.tradingHours.isMarketOpen()
                    return
                }
            }
            isMarketOpen = change
        }
        .onChange(of: watcher.tradingHours, initial: true) {
            isMarketOpen = watcher.tradingHours.isMarketOpen()
        }
    }
    
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
            
            Button(action: { Task { await cancelMarketData(watcher.contract, interval: watcher.interval) }}) {
                Image(systemName: "xmark")
                    .aspectRatio(1, contentMode: .fit)
            }
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
    
    private func cancelMarketData(_ contract: any Contract, interval: TimeInterval) async {
        let asset = Asset(
            instrument: Instrument(
                type: contract.type,
                symbol: contract.symbol,
                exchangeId: contract.exchangeId,
                currency: contract.currency
            ),
            interval: interval
        )
        await MainActor.run {
            _ = watchedAssets.remove(asset)
        }
        trades.cancelMarketData(asset)
    }
    
    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "----.--" }
        return String(format: "%.2f", value)
    }
}

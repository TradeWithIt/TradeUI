import SwiftUI
import Runtime
import Brokerage
import TradingStrategy

public struct SnapshotPlaybackView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("selected.strategy.same") private var selectedStrategyName: String = "Viewing only"
    @State var watcher: Watcher?
    
    let node: FileSnapshotsView.FileNode?
    let fileProvider: MarketDataFileProvider
    
    public init(node: FileSnapshotsView.FileNode?, fileProvider: MarketDataFileProvider) {
        self.node = node
        self.fileProvider = fileProvider
    }
    
    public var body: some View {
        Group {
            if watcher != nil {
                WatcherView(watcher: watcher)
                    .onDisappear(perform: close)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .onAppear(perform: runSimulation)
            }
        }
        .frame(minWidth: 800, minHeight: 450)
        .padding(20)
        .overlay(alignment: .topTrailing) {
            #if !os(macOS)
            Button("Dismiss") {
                close()
                presentationMode.wrappedValue.dismiss()
            }.padding()
            #endif
        }
    }
    
    private func close() {
        guard let watcher else { return }
        fileProvider.unsubscribeMarketData(contract: watcher.contract, interval: watcher.interval)
    }
    
    private func runSimulation() {
        guard let url = node?.url else { return }
        let unknown = StrategyRegistry.shared.strategy(forName: selectedStrategyName)
        let strategyType = unknown ?? StrategyRegistry.shared.defaultStrategyType
        let stratName = unknown == nil ? StrategyRegistry.shared.defaultStrategyName : selectedStrategyName
        let information = node?.name.decodeFileName()
        do {
            let contract = Instrument(type: "", symbol: information?.symbol ?? url.lastPathComponent, exchangeId: "", currency: "")
            self.watcher = try Watcher(
                contract: contract,
                interval: information?.interval ?? 60,
                strategyType: strategyType,
                strategyName: stratName ?? selectedStrategyName,
                tradeAggregator: TradeAggregator(contract: contract),
                fileProvider: fileProvider,
                userInfo: [
                    MarketDataKey.snapshotFileURL.rawValue: url,
                ]
            )
        } catch {
            print("Somethign went wrong while creating watcher: ", error)
        }
    }
}

// MESM4-60.0_20-May-2024_12-28-18
// AAPL-1h-width5
// AAPL-1h-prominence4.csv
private extension String {
    func decodeFileName() -> (symbol: String, interval: TimeInterval)? {
        let sanitizedName = self.components(separatedBy: ".").dropLast().joined(separator: ".")
        let parts = sanitizedName.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        let symbol = String(parts[0])
        let remainder = parts[1].split(separator: "_").first ?? ""
        var intervalString = ""
        var unit: String?

        for char in remainder {
            if char.isNumber || char == "." {
                intervalString.append(char)
            } else if char == "h" || char == "m" {
                unit = String(char)
                break
            } else {
                break
            }
        }

        guard let intervalValue = Double(intervalString) else { return nil }
        let convertedInterval: TimeInterval = (unit == "h") ? intervalValue * 3600 : (unit == "m") ? intervalValue * 60 : intervalValue
        return (symbol, convertedInterval)
    }
}

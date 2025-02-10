import SwiftUI
import Runtime
import Brokerage
import TradingStrategy
import TradeWithIt

struct SnapshotPlaybackView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var watcher: Watcher?
    
    let fileName: String?
    let fileProvider: MarketDataFileProvider
    
    var body: some View {
        Group {
            if let watcher {
                WatcherView(watcher: watcher)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .onAppear(perform: runSimulation)
            }
        }
        .frame(minWidth: 800, minHeight: 450)
        .padding(20)
        .overlay(alignment: .topTrailing) {
            Button("Dismiss") {
                if let watcher {
                    fileProvider.unsubscribeMarketData(symbol: watcher.symbol, interval: watcher.interval)
                }
                presentationMode.wrappedValue.dismiss()
            }.padding()
        }
    }
    
    private func runSimulation() {
        guard let fileName, let information = fileName.decodeFileName() else { return }
        do {
            self.watcher = try Watcher.init(
                symbol: information.symbol,
                interval: information.interval,
                strategyType: SupriseBarStrategy.self,
                marketData: fileProvider,
                fileProvider: fileProvider,
                userInfo: [
                    MarketDataKey.snapshotFileName.rawValue: fileName,
                    MarketDataKey.snapshotPlaybackSpeedInfo.rawValue: 300.0,
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

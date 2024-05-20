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
        .frame(minWidth: 500, minHeight: 450)
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
                    MarketDataKey.snapshotDateInfo.rawValue: information.date,
                    MarketDataKey.snapshotPlaybackSpeedInfo.rawValue: 300.0,
                ]
            )
        } catch {
            print("Somethign went wrong while creating watcher: ", error)
        }
    }
}


private extension String {
    // MESM4-60.0_20-May-2024_12-28-18
    func decodeFileName() -> (symbol: String, interval: TimeInterval, date: Date)? {
        let parts = self.split(separator: "_")
        guard parts.count == 3 else {
            print("Filename format is incorrect")
            return nil
        }
        
        let info = parts[0].split(separator: "-")
        let symbol = String(info[safe: 0] ?? "")
        let intervalString = String(info[safe: 1] ?? "")
        guard let interval = TimeInterval(intervalString) else {
            print("Invalid interval")
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy HH-mm-ss"
        let dateString = parts[1...].joined(separator: " ")
        
        guard let date = dateFormatter.date(from: dateString) else {
            print("Date format is incorrect")
            return nil
        }
        
        return (symbol, interval, date)
    }
}

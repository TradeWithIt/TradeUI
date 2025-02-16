import SwiftUI
import Runtime
import Brokerage
import TradingStrategy
import TradeWithIt

public struct SnapshotView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @State var strategy: (any Strategy)? = nil
    @State var interval: TimeInterval? = nil
    
    let fileName: String?
    let fileProvider: CandleFileProvider
    
    public init(fileName: String?, fileProvider: CandleFileProvider) {
        self.fileName = fileName
        self.fileProvider = fileProvider
    }
    
    public var body: some View {
        Group {
            if let strategy {
                StrategyChart(strategy: strategy, interval: interval ?? 60)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .onAppear(perform: loadData)
            }
        }
        .frame(minWidth: 1000, minHeight: 450)
        .padding(20)
        .overlay(alignment: .topTrailing) {
            Button("Dismiss") {
                if Bundle.main.isMacOS {
                    dismiss()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }.padding()
        }
    }
    
    private func loadData() {
        guard let fileName else { return }
        do {
            let candleData = try fileProvider.loadFile(name: fileName)
            strategy = SupriseBarStrategy(candles: candleData?.bars ?? [])
            interval = candleData?.interval
        } catch {
            print("Failed to load data for:", fileName)
        }
    }
}

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
    @State private var selectedStrategyType: String = "SupriseBarStrategy"
    
    let node: FileSnapshotsView.FileNode?
    let fileProvider: CandleFileProvider
    
    public init(node: FileSnapshotsView.FileNode?, fileProvider: CandleFileProvider) {
        self.node = node
        self.fileProvider = fileProvider
    }
    
    public var body: some View {
        Group {
            VStack {
                strategyPicker
                if let strategy {
                    VStack {
                        StrategyCheckList(strategy: strategy)
                        StrategyChart(strategy: strategy, interval: interval ?? 60)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 450)
        .padding(20)
        .overlay(alignment: .topTrailing) {
            #if !os(macOS)
            Button("Dismiss") {
                if Bundle.main.isMacOS {
                    dismiss()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }.padding()
            #endif
        }
    }
    
    private var strategyPicker: some View {
        Picker("Strategy", selection: $selectedStrategyType) {
            Text("ORBStrategy").tag(String(describing: ORBStrategy.self))
            Text("SupriseBarStrategy").tag(String(describing: SupriseBarStrategy.self))
        }
        .pickerStyle(.automatic)
        .onChange(of: selectedStrategyType, initial: true) {
            switch selectedStrategyType {
            case "ORBStrategy":
                loadData(ORBStrategy.self)
            case "SupriseBarStrategy":
                loadData(SupriseBarStrategy.self)
            default:
                break
            }
        }
        .padding()
    }
    
    private func loadData(_ strat: Strategy.Type) {
        guard let node else { return }
        do {
            let candleData = try fileProvider.loadFile(url: node.url)
            strategy = strat.init(candles: candleData?.bars ?? [])
            interval = candleData?.interval
        } catch {
            print("Failed to load data for:", node.url)
        }
    }
}

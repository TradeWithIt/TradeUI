import SwiftUI
import Foundation
import Runtime

struct OrderView: View {
    @Environment(TradeManager.self) private var trades
    @State private var viewModel = ViewModel()
    @State private var contractNumber: Int32 = 1
    @State private var takeProfit: Int = 25
    @State private var stopLoss: Int = 10
    @State private var whichList = 0
    let watcher: Watcher?
    
    let customDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Foundation.Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "h:mm MM/dd/yy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading) {
            header
            list
            Divider()
            order
        }
        .padding()
        .task {
            Task {
                await refreshOrders()
            }
            Task {
                await refreshPositions()
            }
        }
    }
    
    var header: some View {
        Picker("", selection: $whichList) {
            Text("Orders").tag(0)
            Text("Positions").tag(1)
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    var list: some View {
        switch whichList {
        case 0:
            orderList
        case 1:
            positionList
        default:
            EmptyView()
        }
    }
    
    var orderList: some View {
        List(viewModel.orders) { order in
            HStack {
                Text(order)
//                Text(order.timestamp, formatter: customDateFormatter)
//                Text(order.action == .Buy ? "Buy" : "Sell")
//                Text(order.ordStatus.rawValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            await refreshOrders()
        }
    }
    
    var positionList: some View {
        List(viewModel.positions) { position in
            HStack {
                Text(position)
//                Text(position, formatter: customDateFormatter)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            await refreshOrders()
        }
    }
    
    var order: some View {
        VStack {
            HStack(alignment: .top) {
                Button("Buy Mkt") { print("buy") }
                    .buttonStyle(TradingButtonStyle(backgroundColor: .green))
                Button("Sell Mkt") { print("sell") }
                    .buttonStyle(TradingButtonStyle(backgroundColor: .red))
                HStack(alignment: .top) {
                    Text("Contract Count")
                    TextField("Contract Count", value: $contractNumber, formatter: NumberFormatter())
                }
            }
            HStack(alignment: .top) {
                Text("Take Profit (Market +%)")
                TextField("Take Profit (Market +%)", value: $takeProfit, formatter: NumberFormatter())
            }
            HStack(alignment: .top) {
                Text("Stop Loss (Market -%)")
                TextField("Stop Loss (Market -%)", value: $stopLoss, formatter: NumberFormatter())
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private func refreshOrders() async {
        do {
            viewModel.orders = try await viewModel.orders() ?? []
        } catch {
            viewModel.orders = []
            print("🔴 Failed to load order list", error)
        }
    }
    
    private func refreshPositions() async {
        do {
            viewModel.positions = try await viewModel.positions() ?? []
        } catch {
            viewModel.positions = []
            print("🔴 Failed to load order list", error)
        }
    }
}

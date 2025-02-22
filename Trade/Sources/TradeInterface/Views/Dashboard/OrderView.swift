import SwiftUI
import Foundation
import Runtime
import Brokerage

struct OrderView: View {
    @Environment(TradeManager.self) private var trades
    @State private var contractNumber: Int32 = 1
    @State private var stopLoss: Int = 10
    @State private var whichList = 0
    let watcher: Watcher?
    
    var orders: [Order] {
        trades.market.getOrders()
    }
    
    var positions: [Position] {
        trades.market.getPositions()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            header
            list
            Divider()
            order
        }
        .padding()
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
        List(orders, id: \.orderID) { order in
            HStack {
                HStack(alignment: .top, spacing: 4) {
                    Text("\(order.symbol)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(order.orderAction.rawValue)
                        .fontWeight(.bold)
                        .foregroundColor(order.orderAction == .buy ? .green : .red)
                    Text("\(order.filledCount, specifier: "%.0f")/\(order.totalCount, specifier: "%.0f") @ \(order.limitPrice ?? order.stopPrice ?? 0, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                    
                    Text("\(order.orderStatus)")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var positionList: some View {
        List(positions, id: \.label) { position in
            HStack {
                Text(position.symbol)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var order: some View {
        VStack {
            HStack(alignment: .top) {
                Button("Cancel All") {
                    do {
                        try trades.market.cancelAllOrders()
                    } catch {
                        print(error)
                    }
                    
                }
                Button("Buy Mkt") {
                    guard let watcher, let bar = watcher.strategy.candles.last else { return }
                    do {
                        try trades.market.makeLimitWithTrailingStopOrder(
                            contract: watcher.contract,
                            action: .buy,
                            price: bar.priceHigh,
                            trailStopPrice: bar.priceHigh - (bar.body * Double(stopLoss)),
                            quantity: Double(contractNumber)
                        )
                    } catch {
                        print(error)
                    }
                }
                    .buttonStyle(TradingButtonStyle(backgroundColor: .green))
                Button("Sell Mkt") {
                    guard let watcher, let bar = watcher.strategy.candles.last else { return }
                    do {
                        try trades.market.makeLimitWithTrailingStopOrder(
                            contract: watcher.contract,
                            action: .sell,
                            price: bar.priceLow,
                            trailStopPrice: bar.priceLow + (bar.body * Double(stopLoss)),
                            quantity: Double(contractNumber)
                        )
                    } catch {
                        print(error)
                    }
                }
                    .buttonStyle(TradingButtonStyle(backgroundColor: .red))
                HStack(alignment: .top) {
                    Text("Contract Count")
                    TextField("Contract Count", value: $contractNumber, formatter: NumberFormatter())
                }
            }
            HStack(alignment: .top) {
                Text("Stop Loss (Market -%)")
                TextField("Stop Loss (Market -%)", value: $stopLoss, formatter: NumberFormatter())
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

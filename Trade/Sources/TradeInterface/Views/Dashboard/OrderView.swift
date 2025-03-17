import SwiftUI
import Foundation
import Runtime
import Brokerage

struct OrderView: View {
    enum Style {
        case portfolio, orderEntry
    }
    @Environment(TradeManager.self) private var trades
    @State private var contractNumber: Int32 = 1
    @State private var stopLoss: Int = 75
    let watcher: Watcher?
    let account: Account?
    var show: Style = .orderEntry
    
    var orders: [Order] {
        account?.orders.values.map { $0 } ?? []
    }
    
    var positions: [Position] {
        account?.positions ?? []
    }
    
    var body: some View {
        switch show {
        case .portfolio:
            list
        case .orderEntry:
            order
        }
    }
    
    @ViewBuilder
    var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !positions.isEmpty {
                Text("Positions").font(.headline)
                positionList
            }
            if !orders.isEmpty {
                Text("Orders").font(.headline)
                orderList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    var orderList: some View {
        List(orders, id: \.orderID) { order in
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
                Spacer(minLength: 0)
                Button("Cancel") {
                    do {
                        try trades.market.cancelOrder(orderId: order.orderID)
                    } catch {
                        print(error)
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.headline)
                
                Text("Exchange: \(position.exchangeId) | Currency: \(position.currency)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Quantity: \(position.quantity, specifier: "%.2f")")
                    .font(.body)
                
                Text("Market Value: \(position.marketValue, specifier: "%.2f")")
                    .font(.body)
                
                HStack {
                    Text("U-PNL: \(position.unrealizedPNL, specifier: "%.2f")")
                        .foregroundColor(position.unrealizedPNL >= 0 ? .green : .red)
                    
                    Text("R-PNL: \(position.realizedPNL, specifier: "%.2f")")
                        .foregroundColor(position.realizedPNL >= 0 ? .green : .red)
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Button("Buy Mkt") {
                    Task {
                        let strategy = await watcher?.watcherState.getStrategy()
                        guard let contract = watcher?.contract, let bar = strategy?.charts.first?.last else { return }
                        do {
                            try trades.market.makeLimitWithTrailingStopOrder(
                                contract: contract,
                                action: .buy,
                                price: bar.priceHigh,
                                trailStopPrice: bar.priceHigh - (bar.body * Double(stopLoss) / 100.0),
                                quantity: Double(contractNumber)
                            )
                        } catch {
                            print(error)
                        }
                    }
                }
                .buttonStyle(TradingButtonStyle(backgroundColor: .green))
                Button("Sell Mkt") {
                    Task {
                        let strategy = await watcher?.watcherState.getStrategy()
                        guard let contract = watcher?.contract, let bar = strategy?.charts.first?.last else { return }
                        do {
                            try trades.market.makeLimitWithTrailingStopOrder(
                                contract: contract,
                                action: .sell,
                                price: bar.priceLow,
                                trailStopPrice: bar.priceLow + (bar.body * Double(stopLoss) / 100.0),
                                quantity: Double(contractNumber)
                            )
                        } catch {
                            print(error)
                        }
                    }
                }
                .buttonStyle(TradingButtonStyle(backgroundColor: .red))
                Spacer()
                Button("Cancel All") {
                    do {
                        try trades.market.cancelAllOrders()
                    } catch {
                        print(error)
                    }
                    
                }
                .buttonStyle(TradingButtonStyle(backgroundColor: .gray))
            }
            Divider()
            HStack(alignment: .top) {
                Text("Contract Count")
                Spacer()
                TextField("Contract Count", value: $contractNumber, formatter: NumberFormatter())
                    .frame(width: 80)
            }
            HStack(alignment: .top) {
                Text("Stop Loss (Market %)")
                Spacer()
                TextField("Stop Loss (Market %)", value: $stopLoss, formatter: NumberFormatter())
                    .frame(width: 80)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

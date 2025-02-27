import SwiftUI
import Foundation
import Runtime
import Brokerage

struct OrderView: View {
    @Environment(TradeManager.self) private var trades
    @State private var contractNumber: Int32 = 1
    @State private var stopLoss: Int = 10
    let account: Account?
    let watcher: Watcher?
    
    var orders: [Order] {
        account?.orders.values.map { $0 } ?? []
    }
    
    var positions: [Position] {
        account?.positions ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            list
            Divider()
            order
        }
        .padding()
    }
    
    @ViewBuilder
    var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Positions").font(.headline)
            positionList
            Text("Orders").font(.headline)
            orderList
        }
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
                .buttonStyle(TradingButtonStyle(backgroundColor: .gray))
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

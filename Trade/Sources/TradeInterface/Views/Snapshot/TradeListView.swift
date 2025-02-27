import SwiftUI
import Persistence

struct TradeListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TradeManager.self) private var trades
    @State private var records: [TradeRecord] = []

    var body: some View {
        NavigationView {
            List(records) { trade in
                VStack(alignment: .leading, spacing: 6) {
                    Text("ID: \(trade.id.uuidString.prefix(8))")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        Text(trade.symbol)
                            .font(.headline)
                        Spacer()
                        Text(trade.decision.uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(trade.decision == "Long" ? .green : .red)
                    }

                    HStack {
                        Text("Entry: \(trade.entryPrice, specifier: "%.2f")")
                        Spacer()
                        Text("📅 \(formatDate(trade.entryTime))")
                    }
                    .font(.footnote)

                    if let exitPrice = trade.exitPrice, let exitTime = trade.exitTime {
                        HStack {
                            Text("Exit: \(exitPrice, specifier: "%.2f")")
                            Spacer()
                            Text("📅 \(formatDate(exitTime))")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } else {
                        Text("🔵 Active Trade").font(.footnote).foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Trade History")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear(perform: fetchTrades)
        }
    }

    private func fetchTrades() {
        records = trades.persistance.fetchAllTrades()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TradeListView_Previews: PreviewProvider {
    static var previews: some View {
        TradeListView()
    }
}

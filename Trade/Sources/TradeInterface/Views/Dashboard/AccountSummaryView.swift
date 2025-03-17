import SwiftUI
import Brokerage
import Runtime
import SwiftUIComponents

struct AccountSummaryView: View {
    @AppStorage("trade.alert.message.recipient") private var messageRecipient: String = ""
    @State private var tempPhoneNumber: String = ""
    
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
                Text("Account Name:")
                    .font(.headline)
                Text(account.name)
                    .fontWeight(.bold)
            }
            
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    accountMetricRow(title: "Available Funds", value: account.availableFunds, currency: account.currency)
                    accountMetricRow(title: "Buying Power", value: account.buyingPower, currency: account.currency)
                    accountMetricRow(title: "Net Liquidation", value: account.netLiquidation, currency: account.currency)
                    accountMetricRow(title: "Excess Liquidity", value: account.excessLiquidity, currency: account.currency)
                    accountMetricRow(title: "Initial Margin", value: account.initialMargin, currency: account.currency)
                    accountMetricRow(title: "Maintenance Margin", value: account.maintenanceMargin, currency: account.currency)
                    accountMetricRow(title: "Leverage", value: account.leverage, isPercentage: true)
                }
                Spacer()
            }
            
            Divider()

            HStack {
                Text("Last Updated:")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
                Text(account.updatedAt != nil ? "\(account.updatedAt!.formatted(date: .numeric, time: .shortened))" : "N/A")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Trade Alert Phone Number:")
                    .font(.headline)
                
                SecureField("Enter phone number", text: $tempPhoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if !tempPhoneNumber.isValidPhoneNumber {
                    Text("⚠️ Invalid phone number. Use format +1234567890.")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    HStack {
                        if tempPhoneNumber != messageRecipient {
                            Button("Save Number") {
                                guard tempPhoneNumber.isValidPhoneNumber else { return }
                                messageRecipient = tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .padding(.top, 5)
                        }
                        Button("Test") {
                            let bar = Bar(timeOpen: 0, interval: 0, priceOpen: 0, priceHigh: 0, priceLow: 0, priceClose: 0, volume: 0)
                            let trade = Trade(entryBar: bar, price: 1, trailStopPrice: 2, units: 3)
                            TradeAlertHandler.shared.sendAlert(trade, recentBar: bar)
                        }
                        .padding(.top, 5)
                    }
                }
            }
            
            Divider()
        }
        .padding()
        .onAppear {
            tempPhoneNumber = messageRecipient
        }
    }

    // Helper function to format account metrics
    private func accountMetricRow(title: String, value: Double, currency: String? = nil, isPercentage: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Text(title + ":")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(isPercentage ? String(format: "%.2f%%", value * 100) : formattedCurrency(value: value, currency: currency))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(value < 0 ? .red : .primary)
        }
    }

    // Helper function to format currency values
    private func formattedCurrency(value: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

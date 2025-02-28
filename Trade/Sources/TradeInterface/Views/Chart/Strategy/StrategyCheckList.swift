import SwiftUI
import TradingStrategy


public struct StrategyCheckList: View {
    let strategy: any Strategy
    
    public init(strategy: any Strategy) {
        self.strategy = strategy
    }
    
    public var body: some View {
        HStack {
            ForEach(Array(strategy.patternInformation.keys.sorted()), id: \.self) { key in
                checkItem(name: key) { strategy.patternInformation[key] ?? false }
            }
        }
        .padding(.horizontal)
    }
    
    private func checkItem(name: String, _ condition: () -> Bool) -> some View {
        let isFullfiled: Bool = condition()
        return VStack(alignment: .center, spacing: 4) {
            Text(name)
                .lineLimit(1)
                .foregroundColor(.white.opacity(0.4))
                .font(.caption)
            Text(isFullfiled ? "✔︎" : "✕")
                .lineLimit(1)
                .foregroundColor(isFullfiled ? .green : .red)
                .font(.subheadline)
        }
    }
}

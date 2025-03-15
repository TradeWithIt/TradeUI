import SwiftUI
import TradingStrategy

struct StrategyPicker: View {
    @EnvironmentObject var strategyRegistry: StrategyRegistry
    @Binding var selectedStrategyName: String
    var action: ((_ strat: Strategy.Type) -> Void)? = nil
    
    
    var body: some View {
        Picker("Strategy", selection: $selectedStrategyName) {
            ForEach(strategyRegistry.availableStrategies(), id: \.self) { strategyName in
                Text(strategyName).tag(strategyName)
            }
        }
        .pickerStyle(.automatic)
        .onChange(of: selectedStrategyName, initial: true) {
            guard let strategyType = StrategyRegistry.shared.strategy(forName: selectedStrategyName) else {
                return
            }
            action?(strategyType.self)
        }
        .padding()
    }
}

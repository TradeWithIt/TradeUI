import Foundation
import TradeWithIt
import TradingStrategy

/// A registry for dynamically registering and retrieving trading strategies.
@MainActor
public final class StrategyRegistry: ObservableObject {
    public static let shared = StrategyRegistry()
    public var defaultStrategyType: Strategy.Type = ORBStrategy.self
    public var defaultStrategyName: String? {
        strategyName(for: defaultStrategyType)
    }
    
    /// Holds registered strategy types by name.
    private var strategies: [String: Strategy.Type] = [:]

    public func strategy(forName name: String) -> Strategy.Type? {
        strategies[name]
    }
    
    public func strategyName<T: Strategy>(for type: T.Type) -> String? {
        return strategies.first { $1 == type }?.key
    }

    /// Returns the list of registered strategy names.
    public func availableStrategies() -> [String] {
        return Array(strategies.keys)
    }
    
    /// Registers a strategy by providing its type and a unique name.
    public func register<T: Strategy>(strategyType type: T.Type, name: String) {
        strategies[name] = type
    }
}

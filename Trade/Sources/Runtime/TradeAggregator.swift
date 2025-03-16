import Foundation
import Brokerage

public final class TradeAggregator {
    public var isTradeEntryEnabled: Bool = false
    public var isTradeExitEnabled: Bool = false
    public var isTradeEntryNotificationEnabled: Bool = true
    public var isTradeExitNotificationEnabled: Bool = true
    
    private var marketOrder: MarketOrder?
    
    public init(marketOrder: MarketOrder? = nil) {
        self.marketOrder = marketOrder
    }
    
    public func enterTradeIfStrategyIsValidated(_ request: Request) async {
        guard !Task.isCancelled else { return }
        let hasNoActiveTrade = await request.watcherState.getActiveTrade() == nil
        guard hasNoActiveTrade else { return }
        let strategy = await request.watcherState.getStrategy()
        guard strategy.patternIdentified, let entryBar = strategy.candles.last else { return }
        
        if request.isSimulation {
            let units = strategy.unitCount(entryBar: entryBar, equity: 1_000_000, feePerUnit: 50)
            let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar) ?? 0
            let trade = Trade(
                entryBar: entryBar,
                price: entryBar.priceClose,
                trailStopPrice: initialStopLoss,
                units: Double(units)
            )
            await request.watcherState.updateActiveTrade(trade)
            print("✅🟤 enter trade: ", trade)
        } else if let account = marketOrder?.account {
            // check if
            print("✅ enterTradeIfStrategyIsValidated, symbol: \(request.symbol): intervl: \(request.interval)")
            
            let units = strategy.unitCount(entryBar: entryBar, equity: account.buyingPower, feePerUnit: 50)
            print("✅ enterTradeIfStrategyIsValidated units: ", units)
            guard units > 0 else { return }
            
            let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar)
            print("✅ enterTradeIfStrategyIsValidated stopLoss: ", initialStopLoss ?? 0)
            guard let initialStopLoss else { return }
            
            await evaluateMarketCoonditions(
                trade:
                    Trade(
                        entryBar: entryBar,
                        price: entryBar.priceClose,
                        trailStopPrice: initialStopLoss,
                        units: Double(units)
                    ),
                request: request
            )
        }
    }
    
    private func evaluateMarketCoonditions(trade: Trade, request: Request) async {
        // TODO: 1. Check for market alerts
        
        // Is market open during liquid hours
        let marketOpen = await request.watcherState.getTradingHours()?.isMarketOpen()
        print("✅ evaluateMarketCoonditions: ", marketOpen as Any)
        guard
            let marketOpen,
            marketOpen.isOpen == true,
            let timeUntilClose = marketOpen.timeUntilChange,
            // 30 min before market close
            timeUntilClose > (1_800 * 6)
        else { return }
        
        let hasNoActiveTrade = await request.watcherState.getActiveTrade() == nil
        // Did not enter trade, as there is currently pending trade
        guard hasNoActiveTrade else { return }
        await request.watcherState.updateActiveTrade(trade)
        
        if isTradeEntryNotificationEnabled {
            // TODO: Notify
            print("✅✅ enter trade: ", trade)
        }
        guard isTradeEntryEnabled else { return }
        do {
            try marketOrder?.makeLimitWithTrailingStopOrder(
                contract: request.contract,
                action: trade.entryBar.isLong ? .buy : .sell,
                price: trade.price,
                trailStopPrice: trade.trailStopPrice,
                quantity: trade.units
            )
        } catch {
            print("Something went wrong while exiting trade: \(error)")
        }
    }
    
    public func manageActiveTrade(_ request: Request) async {
        guard !Task.isCancelled else { return }
        let strategy = await request.watcherState.getStrategy()
        
        guard
            let activeTrade = await request.watcherState.getActiveTrade(),
            let recentBar = strategy.candles.last,
            activeTrade.entryBar.timeOpen != recentBar.timeOpen
        else { return }
        
        guard strategy.shouldExit(entryBar: activeTrade.entryBar) else { return }
        
        if isTradeExitNotificationEnabled {
            // TODO: Notify Exit
            print("❌ Exiting trade at \(activeTrade), lastBar: \(recentBar)")
        }
        guard isTradeExitEnabled else { return }
        
        if request.isSimulation {
            await request.watcherState.updateActiveTrade(nil)
        } else {
            guard let account = marketOrder?.account else { return }
            guard let position = account.positions.first(where: { $0.label == request.contract.label }) else { return }
            do {
                try marketOrder?.makeLimitOrder(
                    contract: request.contract,
                    action: activeTrade.entryBar.isLong ? .sell : .buy,
                    price: position.averageCost,
                    quantity: position.quantity
                )
                await request.watcherState.updateActiveTrade(nil)
            } catch {
                print("Something went wrong while exiting trade: \(error)")
            }
        }
    }
    
    // MARK: Types
    
    public struct Request {
        let isSimulation: Bool
        let watcherState: Watcher.WatcherStateActor
        let contract: any Contract
        let interval: TimeInterval
    }
}

public extension TradeAggregator.Request {
    var symbol: String { contract.symbol }
}

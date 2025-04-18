import Foundation
import Brokerage
import TradingStrategy

public final class TradeAggregator: Hashable {
    public var isTradeEntryEnabled: Bool = false
    public var isTradeExitEnabled: Bool = false
    public var isTradeEntryNotificationEnabled: Bool = true
    public var isTradeExitNotificationEnabled: Bool = true
    public var minConfirmations: Int = 1
    
    public let id = UUID()
    public let contract: any Contract
    private var marketOrder: MarketOrder?
    private var tradeSignals: Set<Request> = []
    private let tradeQueue = DispatchQueue(label: "TradeAggregatorQueue", attributes: .concurrent)
    private var stats = TradeStats()
    
    private var getNextTradingAlertsAction: (() -> Annoucment?)?
    private var tradeEntryNotificationAction: ((_ trade: Trade, _ recentBar: Klines) -> Void)?
    private var tradeExitNotificationAction: ((_ trade: Trade, _ recentBar: Klines) -> Void)?
    
    public init(
        contract: any Contract,
        marketOrder: MarketOrder? = nil,
        getNextTradingAlertsAction: (() -> Annoucment?)? = nil,
        tradeEntryNotificationAction: ((_ trade: Trade, _ recentBar: Klines) -> Void)? = nil,
        tradeExitNotificationAction: ((_ trade: Trade, _ recentBar: Klines) -> Void)? = nil
    ) {
        self.marketOrder = marketOrder
        self.contract = contract
        self.getNextTradingAlertsAction = getNextTradingAlertsAction
        self.tradeEntryNotificationAction = tradeEntryNotificationAction
        self.tradeExitNotificationAction = tradeExitNotificationAction
    }
    
    deinit {
        getNextTradingAlertsAction = nil
        tradeEntryNotificationAction = nil
        tradeExitNotificationAction = nil
    }
    
    public func registerTradeSignal(_ request: Request) async {
        let strategy = await request.watcherState.getStrategy()
        if strategy.patternIdentified {
            let contract = contract.label
            let count = tradeQueue.sync(flags: .barrier) { [weak self] in
                self?.tradeSignals.insert(request)
                return self?.tradeSignals.count ?? 0
            }
            
            if count >= minConfirmations {
                let matchingRequest = tradeQueue.sync(flags: .barrier) { [weak self] in
                    self?.tradeSignals.first(where: { $0.contract.label == contract })
                }
                guard let matchingRequest else {
                    print("🔴 Failure to find matching request")
                    return
                }
                await enterTradeIfStrategyIsValidated(matchingRequest)
                tradeQueue.sync(flags: .barrier) { [weak self] in
                    self?.tradeSignals = []
                }
            } else {
                print("⏳ Waiting for more confirmations for \(contract): \(tradeSignals.count)/\(minConfirmations)")
            }
        } else {
            tradeQueue.sync(flags: .barrier) { [weak self] in
                _ = self?.tradeSignals.remove(request)
            }
        }
        await manageActiveTrade(request)
    }
    
    private func enterTradeIfStrategyIsValidated(_ request: Request) async {
        guard !Task.isCancelled else { return }
        let hasNoActiveTrade = await request.watcherState.getActiveTrade() == nil
        guard hasNoActiveTrade else { return }
        let strategy = await request.watcherState.getStrategy()
        guard strategy.patternIdentified, let entryBar = strategy.candles.last else { return }
        
        if request.isSimulation {
            let units = strategy.shouldEnterWitUnitCount(
                entryBar: entryBar,
                equity: 1_000_000,
                feePerUnit: 50,
                nextAnnoucment: nil
            )
            let initialStopLoss = strategy.adjustStopLoss(entryBar: entryBar) ?? 0
            let trade = Trade(
                entryBar: entryBar,
                price: entryBar.priceClose,
                trailStopPrice: initialStopLoss,
                units: Double(units)
            )
            await request.watcherState.updateActiveTrade(trade)
            print("🟤 enter trade: ", trade)
        } else if let account = marketOrder?.account {
            // check if
            print("✅ enterTradeIfStrategyIsValidated, symbol: \(request.symbol): intervl: \(request.interval)")
            let nextEvent = getNextTradingAlertsAction?()
            let units = strategy.shouldEnterWitUnitCount(
                entryBar: entryBar,
                equity: account.buyingPower,
                feePerUnit: 50,
                nextAnnoucment: nextEvent
            )
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
            tradeEntryNotificationAction?(trade, trade.entryBar)
        }
        guard isTradeEntryEnabled else { return }
        do {
            try marketOrder?.makeLimitWithTrailingStopOrder(
                contract: contract,
                action: trade.entryBar.isLong ? .buy : .sell,
                price: trade.price,
                trailStopPrice: trade.trailStopPrice,
                quantity: trade.units
            )
        } catch {
            print("Something went wrong while exiting trade: \(error)")
        }
    }
    
    private func manageActiveTrade(_ request: Request) async {
        guard !Task.isCancelled else { return }
        let strategy = await request.watcherState.getStrategy()
        
        guard
            let activeTrade = await request.watcherState.getActiveTrade(),
            let recentBar = strategy.candles.last,
            activeTrade.entryBar.timeOpen != recentBar.timeOpen
        else { return }
        let nextEvent = getNextTradingAlertsAction?()
        let shouldExit = strategy.shouldExit(entryBar: activeTrade.entryBar, nextAnnoucment: nextEvent)
        let isLongTrade = activeTrade.entryBar.isLong
        let wouldHitStopLoss = isLongTrade ? activeTrade.trailStopPrice >= recentBar.priceClose : activeTrade.trailStopPrice <= recentBar.priceClose
        if shouldExit, isTradeExitNotificationEnabled {
            tradeExitNotificationAction?(activeTrade, recentBar)
        }
        
        if request.isSimulation, shouldExit || wouldHitStopLoss {
            let profit = activeTrade.entryBar.isLong
            ? recentBar.priceClose - activeTrade.price
            : activeTrade.price - recentBar.priceClose
            print("❌ profit: \(profit) entry: \(activeTrade.price) , exit: \(recentBar.priceClose), didHitStopLoss: \(wouldHitStopLoss)")
            stats.recordTrade(entry: activeTrade.price, exit: recentBar.priceClose, isLong: activeTrade.entryBar.isLong)
            await request.watcherState.updateActiveTrade(nil)
        } else if shouldExit, isTradeExitEnabled {
            guard let account = marketOrder?.account else { return }
            guard let position = account.positions.first(where: { $0.label == contract.label }) else { return }
            do {
                try marketOrder?.makeLimitOrder(
                    contract: contract,
                    action: activeTrade.entryBar.isLong ? .sell : .buy,
                    price: position.averageCost,
                    quantity: position.quantity
                )
                print("❌ Exiting trade at \(activeTrade), entryPrice: \(activeTrade.price) , exitPrice: \(recentBar.priceClose), didHitStopLoss: \(wouldHitStopLoss)")
                await request.watcherState.updateActiveTrade(nil)
            } catch {
                print("Something went wrong while exiting trade: \(error)")
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(contract.label)
        hasher.combine(id)
    }
    
    public static func == (lhs: TradeAggregator, rhs: TradeAggregator) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: Types
    
    public struct Request: Hashable {
        let isSimulation: Bool
        let watcherState: Watcher.WatcherStateActor
        let contract: any Contract
        let interval: TimeInterval
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(contract.label)
            hasher.combine(interval)
        }
        
        public static func == (lhs: Request, rhs: Request) -> Bool {
            return lhs.contract.label == rhs.contract.label && lhs.interval == rhs.interval
        }
    }
}

public extension TradeAggregator.Request {
    var symbol: String { contract.symbol }
}

struct TradeStats {
    var longTrades: Int = 0
    var shortTrades: Int = 0
    var longPnL: Double = 0
    var shortPnL: Double = 0

    mutating func recordTrade(entry: Double, exit: Double, isLong: Bool) {
        let profit = isLong ? (exit - entry) : (entry - exit)

        if isLong {
            longTrades += 1
            longPnL += profit
        } else {
            shortTrades += 1
            shortPnL += profit
        }

        print("✅ \(isLong ? "Long" : "Short") trade: profit \(profit), entry \(entry), exit \(exit)")
    }
}

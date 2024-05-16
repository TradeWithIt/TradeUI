import Foundation
import SwiftUI
import TradingStrategy
import OrderedCollections

@Observable class Runtime: Identifiable {
    var symbol: Symbol
    var interval: TimeInterval
    var candles: OrderedSet<Bar> = []
    
    private var isInTrade: Bool = false
    
    var id: String {
        "\(symbol):\(interval)"
    }

    init(symbol: Symbol, interval: TimeInterval) {
        self.symbol = symbol
        self.interval = interval
    }

    func aggregateBars(last bar: Bar, newBar: Bar) -> Bar {
        var updatedBar = newBar
        updatedBar.timeOpen = bar.timeOpen
        
        updatedBar.priceHigh = max(bar.priceHigh, newBar.priceHigh)
        updatedBar.priceLow = min(bar.priceLow, newBar.priceLow)
        updatedBar.priceOpen = bar.priceOpen
        updatedBar.priceClose = newBar.priceClose
        return updatedBar
    }
    
    func updateCandles(bars: [Bar], ib: InteractiveBrokers) {
        var candles = self.candles
        
        if candles.isEmpty {
            candles = OrderedSet(bars)
        } else {
            for bar in bars {
                if let index = candles.lastIndex(of: bar) {
                    // If the bar exists, update it
                    candles.update(bar, at: index)
                } else if let lastBar = candles.last, bar.timeOpen > lastBar.timeOpen {
                    //If the bar is new append it
                    candles.updateOrAppend(bar)
                }
            }
        }
        
        // Higher 15min frame or 4 bars if trading in over 15min resolution.
        let minimumCandleGroupCount = max(4, Int(900.0 / interval))
        let maxCandlesCount = minimumCandleGroupCount * 60

        if candles.count > maxCandlesCount {
            candles.removeFirst(candles.count - maxCandlesCount)
        }

        self.candles = candles
    }

    func validateStrategy(strategy type: Strategy.Type, bars: [any Klines]) -> Bool {
        guard let lastCandleTime = bars.last?.timeOpen else { return false }
        let strategy = type.init(candles: bars)
        guard strategy.patternIdentified else { return false }
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastCandle = currentTime - lastCandleTime
        let timeUntilNextCandle = max(0, interval - timeSinceLastCandle)
        
        guard timeUntilNextCandle < 5 else { return false }
        return !isInTrade
    }
    
    func enterTrade(ib: InteractiveBrokers, lastCandle candle: any Klines) {
        isInTrade = true
        do {
            try makeOrder(
                ib: ib,
                action: candle.isLong ? .buy : .sell,
                orderQty: 1,
                isPPT: true
            )
        } catch {
            isInTrade = false
            print("🔴 failed while entering the trade: ", error)
        }
    }
    
    func makeOrder(
        ib: InteractiveBrokers,
        action: OrderAction,
        orderQty: Int32,
        isPPT: Bool = true
    ) throws {
        try ib.makeOrder(
            symbol: symbol,
            secType: "",
            action: action == .buy ? .buy : .sell,
            totalQuantity: Double(orderQty)
        )
    }
}

import Foundation
import SwiftUI
import TradingStrategy

@Observable class Runtime: Identifiable {
    var symbol: Symbol
    var interval: TimeInterval
    var candles: [Klines] = []
    
    private var isInTrade: Bool = false
    
    var id: String {
        "\(symbol):\(interval)"
    }

    init(symbol: Symbol, interval: TimeInterval) {
        self.symbol = symbol
        self.interval = interval
    }
    
    func updateCandles(bars: [Bar], ib: InteractiveBrokers) {
        var candles = self.candles

        for newBar in bars {
            if let lastCandle = candles.last {
                let nextIntervalStart = lastCandle.timeOpen + interval
                if newBar.timeOpen < nextIntervalStart {
                    // Aggregate this new bar with the last one
                    candles[candles.count - 1] = aggregateBars(last: lastCandle, newBar: newBar)
                } else if newBar.timeOpen == lastCandle.timeOpen {
                    // Exact match in timeOpen, replace last candle
                    candles[candles.count - 1] = newBar
                } else {
                    // New bar starts a new interval, append to the end
                    candles.append(newBar)
                    isInTrade = false
                }
            } else {
                // If there are no candles yet, simply add the new bar
                candles.append(newBar)
                isInTrade = false
            }
        }

        // Higher 15min frame or 4 bars if trading in over 15min resolution.
        let minimumCandleCount = max(4, Int(900.0 / interval))
        if candles.count > minimumCandleCount * 65 {
            candles.removeFirst()
        }

        self.candles = candles
    }

    /// Helper function to aggregate a new bar with an existing last candle
    func aggregateBars(last bar: any Klines, newBar: Bar) -> Bar {
        var updatedBar = newBar
        updatedBar.timeOpen = bar.timeOpen
        
        updatedBar.priceHigh = max(bar.priceHigh, newBar.priceHigh)
        updatedBar.priceLow = min(bar.priceLow, newBar.priceLow)
        updatedBar.priceOpen = bar.priceOpen
        updatedBar.priceClose = newBar.priceClose
        return updatedBar
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

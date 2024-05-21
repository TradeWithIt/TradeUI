import SwiftUI
import TradingStrategy

public struct StrategyChart: View {
    let strategy: any Strategy
    let interval: TimeInterval
    
    private var candles: [any Klines] {
        return strategy.candles
    }
    
    public var body: some View {
        VStack {
            checkList
            chart
        }
    }
    
    private var checkList: some View {
        HStack {
            ForEach(Array(strategy.patterInformatioin.keys.sorted()), id: \.self) { key in
                checkItem(name: key) { strategy.patterInformatioin[key] ?? false }
            }
            Spacer()
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
    
    public var chart: some View {
        ChartView(interval: interval, data: candles)
            .chartOverlay { scale, frame in
                // Simple Moving Average shorTermLength: Int = 8, longTermLength: Int = 24
                
                Path.quadCurvedPathWithPoints(
                    points: strategy.shortTermMA.enumerated()
                        .map({ $0.element.toPoint(atTime: candles[$0.offset].timeCenter, scale: scale, canvasSize: frame.size) }),
                    canvas: frame
                )
                .stroke(Color.purple)
                
                Path.quadCurvedPathWithPoints(
                    points: strategy.longTermMA.enumerated()
                        .map({ $0.element.toPoint(atTime: candles[$0.offset].timeCenter, scale: scale, canvasSize: frame.size) }),
                    canvas: frame
                )
                .stroke(Color.indigo)
                
                Path.quadCurvedPathWithPoints(
                    points: strategy.phaseTermMa.enumerated()
                        .map({ $0.element.toPoint(atTime: candles[$0.offset].timeCenter, scale: scale, canvasSize: frame.size) }),
                    canvas: frame
                )
                .stroke(Color.yellow)
            }
            .chartBackground { scale, frame in
                ForEach(0 ..< strategy.phases.count, id: \.self) { i in
                    let minBar = candles[strategy.phases[i].range].min(by: { (a, b) -> Bool in
                        return Swift.min(a.priceOpen, a.priceClose) < Swift.min(b.priceOpen, b.priceClose)
                    })!
                    let maxBar = candles[strategy.phases[i].range].max(by: { (a, b) -> Bool in
                        return Swift.max(a.priceOpen, a.priceClose) < Swift.max(b.priceOpen, b.priceClose)
                    })!
                    let max = Swift.max(maxBar.priceOpen, maxBar.priceClose)
                    let min = Swift.min(minBar.priceOpen, minBar.priceClose)
                    Rectangle()
                        .fill(strategy.phases[i].type == .time ? Color.green.opacity(0.1) : Color.red.opacity(0.1) )
                        .frame(
                            width: Swift.max(
                                0,
                                scale.width(
                                    candles[strategy.phases[i].range.upperBound].timeClose - candles[strategy.phases[i].range.lowerBound].timeOpen,
                                    size: frame.size
                                )
                            ),
                            height: Swift.max(
                                0,
                                scale.height(
                                    (max - min),
                                    size: frame.size
                                )
                            )
                        )
                        .position(
                            (min + (max - min) * 0.5).toPoint(
                                atTime: candles[strategy.phases[i].range.lowerBound].timeOpen + (candles[strategy.phases[i].range.upperBound].timeClose - candles[strategy.phases[i].range.lowerBound].timeOpen) / 2.0,
                                scale: scale,
                                canvasSize: frame.size
                            )
                        )
                }
            }
    }
}

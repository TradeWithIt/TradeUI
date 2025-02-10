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
                                
                // Support Levels
                ForEach(0 ..< strategy.levels.support.count, id: \.self) { i in
                    let support = strategy.levels.support[i]
                    let point = support.level.toPoint(atTime: support.time, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.red, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.support.count), dash: [5, 5]))
                }
                
                // Resistance  Levels
                ForEach(0 ..< strategy.levels.resistance.count, id: \.self) { i in
                    let resistance = strategy.levels.resistance[i]
                    let point = resistance.level.toPoint(atTime: resistance.time, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.green, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.resistance.count), dash: [5, 5]))
                }
            }
//            .chartBackground { scale, frame in
//                ForEach(0 ..< strategy.phases.count, id: \.self) { i in
//                    let minBar = candles[strategy.phases[i].range].min(by: { (a, b) -> Bool in
//                        return Swift.min(a.priceOpen, a.priceClose) < Swift.min(b.priceOpen, b.priceClose)
//                    })!
//                    let maxBar = candles[strategy.phases[i].range].max(by: { (a, b) -> Bool in
//                        return Swift.max(a.priceOpen, a.priceClose) < Swift.max(b.priceOpen, b.priceClose)
//                    })!
//                    let max = Swift.max(maxBar.priceOpen, maxBar.priceClose)
//                    let min = Swift.min(minBar.priceOpen, minBar.priceClose)
//                    Rectangle()
//                        .fill(phaseColor(for: strategy.phases[i].type))
//                        .frame(
//                            width: Swift.max(
//                                0,
//                                scale.width(
//                                    candles[strategy.phases[i].range.upperBound].timeClose - candles[strategy.phases[i].range.lowerBound].timeOpen,
//                                    size: frame.size
//                                )
//                            ),
//                            height: Swift.max(
//                                0,
//                                scale.height(
//                                    (max - min),
//                                    size: frame.size
//                                )
//                            )
//                        )
//                        .position(
//                            (min + (max - min) * 0.5).toPoint(
//                                atTime: candles[strategy.phases[i].range.lowerBound].timeOpen + (candles[strategy.phases[i].range.upperBound].timeClose - candles[strategy.phases[i].range.lowerBound].timeOpen) / 2.0,
//                                scale: scale,
//                                canvasSize: frame.size
//                            )
//                        )
//                }
//            }
    }
    
    private func phaseColor(for type: PhaseType) -> Color {
        switch type {
        case .uptrend:
            return Color.green.opacity(0.25)
        case .downtrend:
            return Color.red.opacity(0.25)
        }
    }
}

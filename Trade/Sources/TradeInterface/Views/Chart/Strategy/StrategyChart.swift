import SwiftUI
import TradingStrategy

public struct StrategyChart: View {
    let strategy: any Strategy
    let interval: TimeInterval
    
    public init(strategy: any Strategy, interval: TimeInterval) {
        self.strategy = strategy
        self.interval = interval
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            chart(candles: strategy.candles)
            supportChart(candles: strategy.supportBars)
        }
    }

    func chart(candles: [Klines]) -> some View {
        ChartView(interval: interval, data: candles)
            .chartBackground { scale, frame in
                drawPhases(strategy.phases, ofCandles: candles, scale: scale, frame: frame)
            }
            .chartOverlay { scale, frame in
                // Moving Average shorTermLength: Int = 8
                Path.quadCurvedPathWithPoints(
                    points: strategy.shortTermMA.enumerated()
                        .map({ $0.element.yToPoint(atIndex: $0.offset, scale: scale, canvasSize: frame.size) }),
                    canvas: frame
                )
                .stroke(Color.blue)
                
                // Resistance  Levels
                ForEach(0 ..< strategy.levels.resistance.count, id: \.self) { i in
                    let resistance = strategy.levels.resistance[i]
                    let point = resistance.level.yToPoint(atIndex: resistance.index, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.green, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.resistance.count), dash: [5, 5]))
                }
                
                // Support Levels
                ForEach(0 ..< strategy.levels.support.count, id: \.self) { i in
                    let support = strategy.levels.support[i]
                    let point = support.level.yToPoint(atIndex: support.index, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.red, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.support.count), dash: [5, 5]))
                }
                
                // Near Short-Term Moving Average Range
                if let shortTermMA = strategy.shortTermMA.last {
                    let yRange = scale.y.upperBound - scale.y.lowerBound
                    let dynamicThreshold = yRange * 0.025
                    
                    let upperRange = scale.y(shortTermMA + dynamicThreshold, size: frame.size)
                    Path.pathWithPoints(
                        points: [
                            CGPoint(x: frame.minX, y: upperRange),
                            CGPoint(x: frame.maxX, y: upperRange),
                        ],
                        canvas: frame
                    )
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    let lowerRange = scale.y(shortTermMA - dynamicThreshold, size: frame.size)
                    Path.pathWithPoints(
                        points: [
                            CGPoint(x: frame.minX, y: lowerRange),
                            CGPoint(x: frame.maxX, y: lowerRange),
                        ],
                        canvas: frame
                    )
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                
                // Phase line
                /*
                Path.pathWithPoints(
                    points: strategy.phaseTermMa.enumerated()
                        .map({ $0.element.toPoint(atTime: candles[$0.offset].timeCenter, scale: scale, canvasSize: frame.size) })
                        .simplifyLine(epsilon: 38)
                        .map({ $0.0 })
                    ,
                    canvas: frame
                )
                .stroke(Color.yellow)
                 */
            }
    }
    
    @ViewBuilder
    func supportChart(candles: [Klines]) -> some View {
        if !candles.isEmpty {
            ChartView(
                interval: candles.first?.interval ?? 900,
                data: candles
            )
            .chartBackground { scale, frame in
                drawPhases(strategy.supportPhases, ofCandles: candles, scale: scale, frame: frame)
            }
            .chartOverlay { scale, frame in
                // Moving Average longTermLength: Int = 24
                
                Path.quadCurvedPathWithPoints(
                    points: strategy.longTermMA.enumerated()
                        .map({ $0.element.yToPoint(atIndex: $0.offset, scale: scale, canvasSize: frame.size) }),
                    canvas: frame
                )
                .stroke(Color.purple)
                
                // Resistance  Levels
                ForEach(0 ..< strategy.levels.resistance.count, id: \.self) { i in
                    let resistance = strategy.levels.resistance[i]
                    let point = resistance.level.yToPoint(atIndex: resistance.index, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.green, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.resistance.count), dash: [5, 5]))
                }
                
                // Support Levels
                ForEach(0 ..< strategy.levels.support.count, id: \.self) { i in
                    let support = strategy.levels.support[i]
                    let point = support.level.yToPoint(atIndex: support.index, scale: scale, canvasSize: frame.size)
                    Path.pathWithPoints(
                        points: [point, CGPoint(x: frame.maxX, y: point.y)],
                        canvas: frame
                    )
                    .stroke(Color.red, style: StrokeStyle(lineWidth: Double(i + 1) / Double(strategy.levels.support.count), dash: [5, 5]))
                }
            }
        }
    }
    
    private func drawPhases(_ phases: [Phase], ofCandles candles: [Klines], scale: Scale, frame: CGRect) -> some View {
        ForEach(0 ..< phases.count, id: \.self) { i in
            let minBar = candles[phases[i].range].min(by: { (a, b) -> Bool in
                return Swift.min(a.priceOpen, a.priceClose) < Swift.min(b.priceOpen, b.priceClose)
            })!
            let maxBar = candles[phases[i].range].max(by: { (a, b) -> Bool in
                return Swift.max(a.priceOpen, a.priceClose) < Swift.max(b.priceOpen, b.priceClose)
            })!
            let max = Swift.max(maxBar.priceOpen, maxBar.priceClose)
            let min = Swift.min(minBar.priceOpen, minBar.priceClose)
            Rectangle()
                .fill(phaseColor(for: phases[i].type))
                .frame(
                    width: Swift.max(
                        0,
                        scale.width(
                            phases[i].range.length,
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
                    (min + (max - min) * 0.5).yToPoint(
                        atIndex: phases[i].range.lowerBound + (phases[i].range.length / 2),
                        scale: scale,
                        canvasSize: frame.size
                    )
                )
        }
    }
    
    private func phaseColor(for type: PhaseType) -> Color {
        switch type {
        case .uptrend:
            return Color.green.opacity(0.25)
        case .downtrend:
            return Color.red.opacity(0.25)
        case .sideways:
            return Color.blue.opacity(0.25)
        }
    }
}

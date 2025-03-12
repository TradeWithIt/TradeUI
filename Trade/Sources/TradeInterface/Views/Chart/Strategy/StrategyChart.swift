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
        ChartView(interval: interval, data: candles, scale: strategy.scale)
            .chartBackground { context, scale, frame in
                drawPhases(context: &context, strategy.phases, ofCandles: candles, scale: scale, frame: frame)
            }
            .chartOverlay { context, scale, frame in
                drawOverlays(context: &context, strategy: strategy, scale: scale, frame: frame)
            }
    }
    
    @ViewBuilder
    func supportChart(candles: [Klines]) -> some View {
        if !candles.isEmpty {
            ChartView(
                interval: candles.first?.interval ?? 900,
                data: candles,
                scale: strategy.supportScale
            )
            .chartBackground { context, scale, frame in
                drawPhases(context: &context, strategy.supportPhases, ofCandles: candles, scale: scale, frame: frame)
            }
            .chartOverlay { context, scale, frame in
                drawSupportOverlays(context: &context, strategy: strategy, scale: scale, frame: frame)
            }
        }
    }

    private func drawPhases(context: inout GraphicsContext, _ phases: [Phase], ofCandles candles: [Klines], scale: Scale, frame: CGRect) {
        for phase in phases {
            guard let minPrice = candles[phase.range].map({ $0.priceLow }).min(),
                  let maxPrice = candles[phase.range].map({ $0.priceHigh }).max() else { continue }
            
            let rect = CGRect(
                x: scale.x(phase.range.lowerBound, size: frame.size),
                y: scale.y(maxPrice, size: frame.size),
                width: scale.width(phase.range.length, size: frame.size),
                height: abs(scale.y(maxPrice, size: frame.size) - scale.y(minPrice, size: frame.size))
            )

            // Only draw if rect is within screen bounds
            if frame.intersects(rect) {
                context.fill(Path(rect), with: .color(phaseColor(for: phase.type)))
            }
        }
    }

    private func drawOverlays(context: inout GraphicsContext, strategy: any Strategy, scale: Scale, frame: CGRect) {
        var path = Path()

        // Short-Term Moving Average (only draw visible points)
        let shortTermPoints = strategy.shortTermMA.enumerated().compactMap {
            let point = $0.element.yToPoint(atIndex: $0.offset, scale: scale, canvasSize: frame.size)
            return frame.contains(point) ? point : nil
        }
        if shortTermPoints.count > 1 {
            path.addLines(shortTermPoints)
            context.stroke(path, with: .color(.blue))
        }

        // Resistance and Support Levels (only draw visible ones)
        for resistance in strategy.levels.resistance {
            drawDashedLine(context: &context, yLevel: resistance.level, index: resistance.index, scale: scale, frame: frame, color: .green)
        }
        for support in strategy.levels.support {
            drawDashedLine(context: &context, yLevel: support.level, index: support.index, scale: scale, frame: frame, color: .red)
        }

        // Near Short-Term Moving Average Range (only draw if visible)
        if let lastShortTermMA = strategy.shortTermMA.last {
            let dynamicThreshold = (scale.y.upperBound - scale.y.lowerBound) * 0.025
            drawDashedLine(context: &context, yLevel: lastShortTermMA + dynamicThreshold, index: 0, scale: scale, frame: frame, color: .blue)
            drawDashedLine(context: &context, yLevel: lastShortTermMA - dynamicThreshold, index: 0, scale: scale, frame: frame, color: .blue)
        }
    }

    private func drawSupportOverlays(context: inout GraphicsContext, strategy: any Strategy, scale: Scale, frame: CGRect) {
        var path = Path()

        // Long-Term Moving Average (only draw visible points)
        let longTermPoints = strategy.longTermMA.enumerated().compactMap {
            let point = $0.element.yToPoint(atIndex: $0.offset, scale: scale, canvasSize: frame.size)
            return frame.contains(point) ? point : nil
        }
        if longTermPoints.count > 1 {
            path.addLines(longTermPoints)
            context.stroke(path, with: .color(.purple))
        }

        // Resistance and Support Levels (only draw visible ones)
        for (i, resistance) in strategy.levels.resistance.enumerated() {
            drawDashedLine(context: &context, yLevel: resistance.level, index: resistance.index, scale: scale, frame: frame, color: .green, lineWidth: Double(i + 1))
        }
        for (i, support) in strategy.levels.support.enumerated() {
            drawDashedLine(context: &context, yLevel: support.level, index: support.index, scale: scale, frame: frame, color: .red, lineWidth: Double(i + 1))
        }
    }

    private func drawDashedLine(context: inout GraphicsContext, yLevel: Double, index: Int, scale: Scale, frame: CGRect, color: Color, lineWidth: Double = 1) {
        let point = yLevel.yToPoint(atIndex: index, scale: scale, canvasSize: frame.size)

        // Only draw if it's inside the frame
        if frame.contains(point) {
            var path = Path()
            path.move(to: CGPoint(x: frame.minX, y: point.y))
            path.addLine(to: CGPoint(x: frame.maxX, y: point.y))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, dash: [5, 5]))
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

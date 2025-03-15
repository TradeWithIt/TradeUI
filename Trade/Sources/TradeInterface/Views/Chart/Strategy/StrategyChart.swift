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
            ForEach(0 ..< strategy.charts.count, id: \.self) { index in
                chart(
                    candles: strategy.charts[safe: index] ?? [],
                    chartScale: strategy.resolution[safe: index] ?? Scale(data: []),
                    phases: strategy.distribution[safe: index] ?? [],
                    indicators: strategy.indicators[safe: index] ?? [:],
                    levels: strategy.levels
                )
            }
        }
    }
    
    @ViewBuilder
    func chart(
        candles: [Klines],
        chartScale: Scale,
        phases: [Phase],
        indicators: [String: [Double]],
        levels: [Level]
    ) -> some View {
        if !candles.isEmpty {
            ChartView(
                interval: candles.first?.interval ?? interval,
                data: candles,
                scale: chartScale
            )
            .chartBackground { context, scale, frame in
                drawPhases(context: &context, phases: phases, ofCandles: candles, scale: scale, frame: frame)
            }
            .chartOverlay { context, scale, frame in
                drawSupportOverlays(context: &context, indicators: indicators, levels: levels, scale: scale, frame: frame)
            }
        }
    }
    
    private func drawPhases(
        context: inout GraphicsContext,
        phases: [Phase],
        ofCandles candles: [Klines],
        scale: Scale,
        frame: CGRect
    ) {
        for phase in phases {
            guard let minPrice = candles[phase.range].map({ $0.priceLow }).min(),
                  let maxPrice = candles[phase.range].map({ $0.priceHigh }).max() else { continue }
            
            let rect = CGRect(
                x: scale.x(phase.range.lowerBound, size: frame.size),
                y: scale.y(maxPrice, size: frame.size),
                width: scale.width(phase.range.length, size: frame.size),
                height: abs(scale.y(maxPrice, size: frame.size) - scale.y(minPrice, size: frame.size))
            )
            
            if frame.intersects(rect) {
                context.fill(Path(rect), with: .color(phaseColor(for: phase.type)))
            }
        }
    }
    
    private func drawSupportOverlays(
        context: inout GraphicsContext,
        indicators: [String: [Double]],
        levels: [Level],
        scale: Scale,
        frame: CGRect
    ) {
        for (index, (name, values)) in indicators.enumerated() {
            let hue = filteredHue(index: index, total: indicators.count)
            let indicatorColor = Color(hue: hue, saturation: 1, brightness: 1)
            var path = Path()
            let points = values.enumerated().compactMap {
                let point = $0.element.yToPoint(atIndex: $0.offset, scale: scale, canvasSize: frame.size)
                return frame.contains(point) ? point : nil
            }
            if points.count > 1 {
                path.addLines(points)
                context.stroke(path, with: .color(indicatorColor), lineWidth: 1)
                
                if let lastPoint = points.last {
                    let labelRect = CGRect(x: frame.maxX - 50, y: lastPoint.y - 20, width: 50, height: 20)
                    context.draw(
                        Text(name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(indicatorColor)
                        ,in: labelRect
                    )
                }
            }
        }
        
        for level in levels {
            drawDashedLine(
                context: &context,
                yLevel: level.level,
                index: level.index,
                scale: scale,
                frame: frame,
                color: .cyan
            )
        }
    }

    private func drawDashedLine(context: inout GraphicsContext, yLevel: Double, index: Int, scale: Scale, frame: CGRect, color: Color, lineWidth: Double = 1) {
        let yPosition = scale.y(yLevel, size: frame.size)
        if yPosition >= frame.minY && yPosition <= frame.maxY {
            var path = Path()
            let startX = frame.minX
            let endX = frame.maxX
            path.move(to: CGPoint(x: startX, y: yPosition))
            path.addLine(to: CGPoint(x: endX, y: yPosition))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, dash: [5, 5]))
            
            let labelRect = CGRect(x: endX - 50, y: yPosition - 20, width: 50, height: 20)
            context.draw(
                Text("\(yLevel.formatted())")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan),
                in: labelRect
            )
        }
    }
    
    private func filteredHue(index: Int, total: Int) -> Double {
        let neonHues: [Double] = [
            200,  // Electric Cyan
            315,  // Hot Pink
            130,  // Neon Lime Green
            275,  // Electric Violet
            55,   // Neon Yellow
            25    // Hot Orange
        ]
        
        return neonHues[index % neonHues.count] / 360.0
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

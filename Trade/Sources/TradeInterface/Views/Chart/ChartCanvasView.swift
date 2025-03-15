import SwiftUI
import TradingStrategy

public struct ChartCanvasView: View {
    public let scale: Scale
    public let data: [Klines]
    
    private var lineWidth: Double = 1
    private var lineStrokeColor: Color = Color.gray.opacity(0.4)
    
    private var canvasOverlay: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void
    private var canvasBackground: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void
    
    public init(
        scale: Scale,
        data: [Klines],
        overlay: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in },
        background: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in }
    ) {
        self.scale = scale
        self.data = data
        self.canvasOverlay = overlay
        self.canvasBackground = background
    }
    
    public var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size)
            drawScales(context: &context, frame: frame)
            canvasBackground(&context, scale, frame)
            drawCandles(context: &context, data: data, scale: scale, frame: frame)
            canvasOverlay(&context, scale, frame)
        }
        .clipped()
    }
    
    private func drawCandles(context: inout GraphicsContext, data: [Klines], scale: Scale, frame: CGRect) {
        let candleWidth = (frame.width / Double(scale.candlesPerScreen)) * 0.9
        // Determine visible candle range
        let firstVisibleIndex = max(0, scale.index(forX: frame.minX, size: frame.size))
        let lastVisibleIndex = min(data.count - 1, scale.index(forX: frame.maxX, size: frame.size))
        
        guard firstVisibleIndex <= lastVisibleIndex else { return }
        for index in firstVisibleIndex...lastVisibleIndex {
            drawCandle(context: &context, kline: data[index], index: index, frame: frame, candleWidth: candleWidth)
        }
    }
    
    private func drawCandle(context: inout GraphicsContext, kline: Klines, index: Int, frame: CGRect, candleWidth: Double) {
        let offsetX = scale.x(index, size: frame.size)
        let highY = scale.y(kline.priceHigh, size: frame.size)
        let lowY = scale.y(kline.priceLow, size: frame.size)
        let openY = scale.y(kline.priceOpen, size: frame.size)
        let closeY = scale.y(kline.priceClose, size: frame.size)
        
        let candleColor: Color = kline.isLong ? .green : .red
        
        // Skip drawing if the candle is completely outside the frame
        if offsetX + candleWidth < frame.minX || offsetX - candleWidth > frame.maxX {
            return
        }
        
        // Wick (Vertical line)
        var wickPath = Path()
        wickPath.move(to: CGPoint(x: offsetX, y: highY))
        wickPath.addLine(to: CGPoint(x: offsetX, y: lowY))
        context.stroke(wickPath, with: .color(candleColor.opacity(0.6)), lineWidth: candleWidth * 0.2)
        // Body (Rectangle)
        let bodyRect = CGRect(
            x: offsetX - candleWidth / 2,
            y: min(openY, closeY),
            width: candleWidth,
            height: abs(openY - closeY)
        )
        
        context.fill(Path(bodyRect), with: .color(candleColor))
    }
        
    private func drawScales(context: inout GraphicsContext, frame: CGRect) {
        let yStep = scale.yGuideStep
        let xStep = scale.xGuideStep
        let textFont = Font.system(size: 10)
        let lineColor = Color.gray.opacity(0.5)
        let lineWidth: Double = 0.8

        let formatter = DateFormatter()
        var calendar = Foundation.Calendar(identifier: .gregorian)
        let timezone = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = timezone
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm\ndd.MM.yy"
        formatter.timeZone = timezone

        var gridPath = Path()
        for i in 0...10 {
            let price = scale.y.lowerBound + (yStep * Double(i))
            let yPos = scale.y(price, size: frame.size)

            guard yPos >= frame.minY, yPos <= frame.maxY else { continue }

            gridPath.move(to: CGPoint(x: frame.minX, y: yPos))
            gridPath.addLine(to: CGPoint(x: frame.maxX, y: yPos))


            let priceString = String(format: "%.2f", price)
            let text = Text(priceString).font(textFont).foregroundColor(.gray)
            context.draw(
                text,
                at: CGPoint(x: frame.minX + 20, y: yPos - 5),
                anchor: .leading
            )
        }

        for i in stride(from: scale.x.lowerBound, to: scale.x.upperBound, by: xStep) {
            let xPos = scale.x(i, size: frame.size)

            guard xPos >= frame.minX, xPos <= frame.maxX, i < data.count else { continue }

            let date = Date(timeIntervalSince1970: data[i].timeOpen)
            let timeString = formatter.string(from: date)

            gridPath.move(to: CGPoint(x: xPos, y: frame.minY))
            gridPath.addLine(to: CGPoint(x: xPos, y: frame.maxY))

            let text = Text(timeString).font(textFont).foregroundColor(.gray)
            context.draw(
                text,
                at: CGPoint(x: xPos, y: frame.maxY),
                anchor: .bottomLeading
            )
        }

        context.stroke(gridPath, with: .color(lineColor), lineWidth: lineWidth)
    }
}

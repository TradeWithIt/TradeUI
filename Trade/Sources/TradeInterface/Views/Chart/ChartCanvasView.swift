import SwiftUI
import TradingStrategy

public struct ChartCanvasView: View {
    public let scale: Scale
    public let data: [Klines]

    private var verticalLines: Int
    private var horizontalLines: Int
    private var lineWidth: Double = 1
    private var lineStrokeColor: Color = Color.gray.opacity(0.4)

    private var canvasOverlay: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void
    private var canvasBackground: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void


    private var shouldDrawGrid: Bool {
        horizontalLines > 0 && verticalLines > 0
    }

    public init(
        scale: Scale,
        data: [Klines],
        verticalLines: Int = 0,
        horizontalLines: Int = 0,
        overlay: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in },
        background: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in }
    ) {
        self.scale = scale
        self.data = data
        self.verticalLines = verticalLines
        self.horizontalLines = horizontalLines
        self.canvasOverlay = overlay
        self.canvasBackground = background
    }

    public var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size)

            canvasBackground(&context, scale, frame)
            
            if shouldDrawGrid {
                drawGrid(context: &context, frame: frame)
            }

            for (index, kline) in data.enumerated() {
                drawCandle(context: &context, kline: kline, index: index, frame: frame)
            }
            
            canvasOverlay(&context, scale, frame)
        }
        .clipped()
    }

    private func drawCandle(context: inout GraphicsContext, kline: Klines, index: Int, frame: CGRect) {
        let offsetX = scale.x(index, size: frame.size)
        
        let candleWidth = (frame.width / Double(scale.candlesPerScreen)) * 0.9
        let highY = scale.y(kline.priceHigh, size: frame.size)
        let lowY = scale.y(kline.priceLow, size: frame.size)
        let openY = scale.y(kline.priceOpen, size: frame.size)
        let closeY = scale.y(kline.priceClose, size: frame.size)

        let candleColor: Color = kline.isLong ? .green : .red

        // Wick (Vertical line)
        var wickPath = Path()
        wickPath.move(to: CGPoint(x: offsetX, y: highY))
        wickPath.addLine(to: CGPoint(x: offsetX, y: lowY))
        context.stroke(wickPath, with: .color(candleColor.opacity(0.6)), lineWidth:  candleWidth * 0.2)

        // Body (Rectangle)
        let bodyRect = CGRect(
            x: offsetX - candleWidth / 2,
            y: min(openY, closeY),
            width: candleWidth,
            height: abs(openY - closeY)
        )
        
        context.fill(Path(bodyRect), with: .color(candleColor))
    }

    private func drawGrid(context: inout GraphicsContext, frame: CGRect) {
        var path = Path()

        let verticalOffset = frame.height / Double(horizontalLines)
        for i in 1...horizontalLines {
            let y = verticalOffset * Double(i) - verticalOffset / 2
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: frame.width, y: y))
        }

        let horizontalOffset = frame.width / Double(verticalLines)
        for i in 1...verticalLines {
            let x = horizontalOffset * Double(i) - horizontalOffset / 2
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: frame.height))
        }

        context.stroke(path, with: .color(lineStrokeColor), lineWidth: lineWidth)
    }
}

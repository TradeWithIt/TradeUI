import SwiftUI
import TradingStrategy

public struct ChartCanvasView<O: View, B: View>: View {
    public let scale: Scale
    public let data: [Klines]
    
    private var verticalLines: Int
    private var horizontalLines: Int
    private var lineWidth: Double = 1
    private var lineStrokeColor: Color = Color.gray.opacity(0.4)
    
    private var canvasOverlay: (_ scale: Scale, _ frame: CGRect) -> O
    private var canvasBackground: (_ scale: Scale, _ frame: CGRect) -> B
    
    private var shouldDrawGrid: Bool {
        horizontalLines > 0 && verticalLines > 0
    }
    
    public init(
        scale: Scale,
        data: [Klines],
        verticalLines: Int = 0,
        horizontalLines: Int = 0,
        overlay: @escaping (_ scale: Scale, _ frame: CGRect) -> O,
        background: @escaping (_ scale: Scale, _ frame: CGRect) -> B
    ) {
        self.scale = scale
        self.data = data
        self.verticalLines = verticalLines
        self.horizontalLines = horizontalLines
        self.canvasOverlay = overlay
        self.canvasBackground = background
    }
    
    public var body: some View {
        GeometryReader { proxy in
            if shouldDrawGrid {
                drawGrid(frame: proxy.frame(in: .local))
            }
            canvasBackground(scale, proxy.frame(in: .local))
            ForEach(Array(data.enumerated()), id: \.element.timeOpen) { index, kline in
                drawCandle(kline: kline, proxy: proxy)
                    .onTapGesture {
                        print("🕯️ Tapped index: \(index), Kline: \(kline)")
                    }
            }
            canvasOverlay(scale, proxy.frame(in: .local))
        }
        .clipped()
    }

    private func drawCandle(kline: Klines, proxy: GeometryProxy) -> some View {
        let offsetX = (kline.timeOpen - scale.x.lowerBound) / scale.amplitiude.width * proxy.size.width
        let offsetY = (Double(scale.y.upperBound) - kline.priceHigh) / scale.amplitiude.height * proxy.size.height
        return CandleView(
            kline: kline,
            canvasSize: proxy.size,
            scale: .init(x: scale.amplitiude.width, y: scale.amplitiude.height)
        )
        .offset(x: offsetX, y: offsetY)
    }

    private func drawGrid(frame: CGRect) -> some View {
        Path { path in
            let verticalOffset = frame.size.height / Double(horizontalLines)
            for i in 1...horizontalLines {
                let y = verticalOffset * Double(i) - verticalOffset / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: frame.width, y: y))
            }
            
            let horizontalOffset = frame.size.width / Double(verticalLines)
            for i in 1...verticalLines {
                let x = horizontalOffset * Double(i) - horizontalOffset / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: frame.height))
            }
        }.stroke(lineStrokeColor, lineWidth: lineWidth)
    }

    // MARK: Modifiers
    
    func backgroundGrid(verticalLines: Int, horizontalLines: Int) -> Self {
        var view = self
        view.verticalLines = verticalLines
        view.horizontalLines = horizontalLines
        return view
    }

    func backgroundLineWidth(_ lineWidth: Double) -> Self {
        var view = self
        view.lineWidth = lineWidth
        return view
    }
    
    func backgroundLineStrokeColor(_ lineStrokeColor: Color) -> Self {
        var view = self
        view.lineStrokeColor = lineStrokeColor
        return view
    }
    
    
    // MARK: Modifiers
    
    public func chartBackground<Content: View>(@ViewBuilder _ view: @escaping (_ scale: Scale, _ frame: CGRect) -> Content) -> ChartCanvasView<O, Content> {
        ChartCanvasView<O, Content>(
            scale: scale,
            data: data,
            verticalLines: verticalLines,
            horizontalLines: horizontalLines,
            overlay: canvasOverlay,
            background: view
        )
    }
    
    public func chartOverlay<Content: View>(@ViewBuilder _ view: @escaping (_ scale: Scale, _ frame: CGRect) -> Content) -> ChartCanvasView<Content, B> {
        ChartCanvasView<Content, B>(
            scale: scale,
            data: data,
            verticalLines: verticalLines,
            horizontalLines: horizontalLines,
            overlay: view,
            background: canvasBackground
        )
    }
}

// MARK: Convinience Initialisers

public extension ChartCanvasView where O == EmptyView {
    init(
        scale: Scale,
        data: [Klines],
        verticalLines: Int = 0,
        horizontalLines: Int = 0,
        background: @escaping (_ scale: Scale, _ frame: CGRect) -> B
    ) {
        self.init(
            scale: scale,
            data: data,
            verticalLines: verticalLines,
            horizontalLines: horizontalLines,
            overlay: { _, _  in EmptyView() },
            background: background
        )
    }
}

public extension ChartCanvasView where B == EmptyView {
    init(
        scale: Scale,
        data: [Klines],
        verticalLines: Int = 0,
        horizontalLines: Int = 0,
        overlay: @escaping (_ scale: Scale, _ frame: CGRect) -> O
    ) {
        self.init(
            scale: scale,
            data: data,
            verticalLines: verticalLines,
            horizontalLines: horizontalLines,
            overlay: overlay,
            background: { _, _ in EmptyView() }
        )
    }
}

public extension ChartCanvasView where O == EmptyView, B == EmptyView {
    init(
        scale: Scale,
        data: [Klines],
        verticalLines: Int = 0,
        horizontalLines: Int = 0
    ) {
        self.init(
            scale: scale,
            data: data,
            verticalLines: verticalLines,
            horizontalLines: horizontalLines,
            overlay: { _, _  in EmptyView() },
            background: { _, _ in EmptyView() }
        )
    }
}

struct ChartCanvasView_Previews: PreviewProvider {
    private struct Bar: Klines {
        var timeOpen: TimeInterval = 0
        var interval: TimeInterval = 60

        var priceOpen: Double = 110
        var priceHigh: Double = 105
        var priceLow: Double = 100
        var priceClose: Double = 95
    }

    static var previews: some View {
        ChartCanvasView(
            scale: .init(),
            data: []
        )
    }
}

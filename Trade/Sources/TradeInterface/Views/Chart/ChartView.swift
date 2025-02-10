import SwiftUI
import TradingStrategy

public struct ChartView<O: View, B: View>: View {
    @State private var labelsVertical: [Double] = []
    @State private var labelsHorizontal: [String] = []
    @State private var scale = Scale()
    @State private var scaleOriginal = Scale()
    @State private var scaleDrag: Scale? = nil
    @State private var canvasSize: CGSize = .zero
    @State private var isManuallyDisplaced: Bool = false
    
    public let data: [Klines]
    public let interval: TimeInterval
    
    private var canvasOverlay: (_ scale: Scale, _ frame: CGRect) -> O
    private var canvasBackground: (_ scale: Scale, _ frame: CGRect) -> B
    
    private var isScaleMoved: Bool {
        scale.x != scaleOriginal.x || scale.y != scaleOriginal.y
    }
    
    public init(
        interval: TimeInterval,
        data: [Klines],
        overlay: @escaping (_ scale: Scale, _ frame: CGRect) -> O,
        background: @escaping (_ scale: Scale, _ frame: CGRect) -> B
    ) {
        self.data = data
        self.interval = interval
        self.canvasOverlay = overlay
        self.canvasBackground = background
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ChartCanvasView(
                    scale: scale,
                    data: data,
                    verticalLines: labelsHorizontal.count,
                    horizontalLines: labelsVertical.count,
                    overlay: canvasOverlay,
                    background: canvasBackground
                )
                .onSizeChange($canvasSize)
                .contentShape(Rectangle())
                .gesture(canvasGesture())
                .border(Color.gray, width: 1)
                
                ScaleView(orientation: .vertical, labels: labelsVertical)
                    .frame(width: 80)
                    .contentShape(Rectangle())
                    .gesture(yRangeGesture())
            }
            HStack(spacing: 0) {
                ScaleView(orientation: .horizontal, labels: labelsHorizontal)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                    .gesture(xRangeGesture())
                Text("Reset")
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .frame(width: 80, height: 50)
                    .foregroundColor(isScaleMoved ? Color.yellow.opacity(0.6) : Color.yellow.opacity(0.2))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: resetScales)
            }
        }
        .border(Color.gray, width: 1)
        .onChange(of: data.last?.timeOpen, initial: true) {
            Task {
                let newScale = Scale(data: data, interval: interval)
                await MainActor.run {
                    scaleOriginal = newScale
                    if !isManuallyDisplaced {
                        self.scale = newScale
                    }
                    updateScales(x: scale.x, y: scale.y)
                }
            }
        }
        .onChange(of: scaleOriginal) {
            guard !isManuallyDisplaced else { return }
            resetScales()
        }
    }
    
    // MARK: – Gestures
    
    private func canvasGesture() -> some Gesture {
        DragGesture().onChanged { gesture in
            let scaleX = scaleDrag?.x ?? scaleOriginal.x
            let scaleY = scaleDrag?.y ?? scaleOriginal.y
            let xValueChange = (gesture.translation.width / canvasSize.width) * scale.xAmplitiude
            let yValueChange = (gesture.translation.height / canvasSize.height) * scale.yAmplitiude
            scale = Scale(
                x: (scaleX.lowerBound - xValueChange)..<(scaleX.upperBound - xValueChange),
                y: (scaleY.lowerBound + yValueChange)..<(scaleY.upperBound + yValueChange)
            )
            updateScales(x: scale.x, y: scale.y)
        }.onEnded { _ in
            scaleDrag = scale
            isManuallyDisplaced = true
        }
    }
    
    private func yRangeGesture() -> some Gesture {
        DragGesture().onChanged { gesture in
            guard abs(gesture.translation.width) < abs(gesture.translation.height) else { return }
            let scaleY = scaleDrag?.y ?? scaleOriginal.y
            let yValueChange = (gesture.translation.height / canvasSize.height) * scale.yAmplitiude
            let lower = scaleY.lowerBound - yValueChange
            let upper = scaleY.upperBound + yValueChange
            if lower > 0, upper > 0, lower < upper {
                scale.y = lower..<upper
                updateScales(y: scale.y)
            }
        }.onEnded { _ in
            scaleDrag = scale
            isManuallyDisplaced = true
        }
    }
    
    private func xRangeGesture() -> some Gesture {
        DragGesture().onChanged { gesture in
            guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
            let scaleX = scaleDrag?.x ?? scaleOriginal.x
            let xValueChange = (gesture.translation.width / canvasSize.width) * scale.xAmplitiude
            let lower = scaleX.lowerBound - xValueChange
            let upper = scaleX.upperBound + xValueChange
            if lower > 0, upper > 0, lower < upper, (upper - lower) >= 10.0 {
                scale.x = lower..<upper
                updateScales(x: scale.x)
            }
        }.onEnded { _ in
            scaleDrag = scale
            isManuallyDisplaced = true
        }
    }
    
    private func resetScales() {
        guard isScaleMoved else { return }
        scaleDrag = scaleOriginal
        scale = scaleOriginal
        isManuallyDisplaced = false
        updateScales(x: scale.x, y: scale.y)
    }
    
    private func updateScales(x: Range<TimeInterval>? = nil, y: Range<Double>? = nil) {
        if let x = x {
            var times: [String] = []
            let formatter = DateFormatter()
            var calendar = Foundation.Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            formatter.calendar = calendar
            formatter.dateFormat = "HH:mm:ss a\ndd.MM"
            
            var date = Date(timeIntervalSince1970: x.lowerBound + scale.xGuideStep / 2)
            while date <= Date(timeIntervalSince1970: x.upperBound) {
                times.append(formatter.string(from: date))
                date = calendar.date(byAdding: .second, value: Int(scale.xGuideStep), to: date)!
            }
            withAnimation { labelsHorizontal = times }
        }
        if let y = y, scale.yGuideStep > 0 {
            let vert: [Double] = Array(
                stride(
                    from: y.lowerBound,
                    to: y.upperBound,
                    by: scale.yGuideStep
                )
            ).reversed()
            withAnimation {
                labelsVertical = vert
            }
        }
    }
    
    
    // MARK: Modifiers
    
    public func chartBackground<Content: View>(@ViewBuilder _ view: @escaping (_ scale: Scale, _ frame: CGRect) -> Content) -> ChartView<O, Content> {
        ChartView<O, Content>(
            interval: interval,
            data: data,
            overlay: canvasOverlay,
            background: view
        )
    }
    
    public func chartOverlay<Content: View>(@ViewBuilder _ view: @escaping (_ scale: Scale, _ frame: CGRect) -> Content) -> ChartView<Content, B> {
        ChartView<Content, B>(
            interval: interval,
            data: data,
            overlay: view,
            background: canvasBackground
        )
    }
}

// MARK: Convinience Initialisers

public extension ChartView where O == EmptyView {
    init(
        interval: TimeInterval,
        data: [Klines],
        background: @escaping (_ scale: Scale, _ frame: CGRect) -> B
    ) {
        self.init(
            interval: interval,
            data: data,
            overlay: { _, _  in EmptyView() },
            background: background
        )
    }
}

public extension ChartView where B == EmptyView {
    init(
        interval: TimeInterval,
        data: [Klines],
        overlay: @escaping (_ scale: Scale, _ frame: CGRect) -> O
    ) {
        self.init(
            interval: interval,
            data: data,
            overlay: overlay,
            background: { _, _ in EmptyView() }
        )
    }
}

public extension ChartView where O == EmptyView, B == EmptyView {
    init(
        interval: TimeInterval,
        data: [Klines]
    ) {
        self.init(
            interval: interval,
            data: data,
            overlay: { _, _  in EmptyView() },
            background: { _, _ in EmptyView() }
        )
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView(interval: 60, data: [])
    }
}

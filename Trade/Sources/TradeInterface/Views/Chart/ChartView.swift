import SwiftUI
import TradingStrategy

public struct ChartView: View {
    @State private var labelsVertical: [Double] = []
    @State private var labelsHorizontal: [String] = []
    @State private var scale = Scale()
    @State private var scaleDrag: Scale? = nil
    @State private var canvasSize: CGSize = .zero
    @State private var isManuallyDisplaced: Bool = false
    
    public let data: [Klines]
    public let interval: TimeInterval
    public var scaleOriginal: Scale
    private var canvasOverlay: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void
    private var canvasBackground: (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void
    
    private var isScaleMoved: Bool {
        scale.x != scaleOriginal.x || scale.y != scaleOriginal.y
    }
    
    public init(
        interval: TimeInterval,
        data: [Klines],
        scale: Scale,
        overlay: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in },
        background: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void = { _, _, _ in }
    ) {
        self.data = data
        self.interval = interval
        self.scaleOriginal = scale
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
        .overlay(alignment: .topLeading) {
            IntervalLabelView(interval: interval, backgroundColor: Color.black.opacity(0.7))
        }
        .onChange(of: data.last?.timeOpen, initial: true) {
            if !isManuallyDisplaced {
                self.scale = scaleOriginal
            }
            updateScales(x: scale.x, y: scale.y)
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
            let xValueChange = (gesture.translation.width / canvasSize.width) * scale.xAmplitude
            let yValueChange = (gesture.translation.height / canvasSize.height) * scale.yAmplitude
            
            let barCount = scale.barCount(forLength: xValueChange, size: canvasSize)
            scale = Scale(
                x: (scaleX.lowerBound - barCount)..<(scaleX.upperBound - barCount),
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
            let yValueChange = (gesture.translation.height / canvasSize.height) * scale.yAmplitude
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
            let xValueChange = (gesture.translation.width / canvasSize.width) * scale.xAmplitude
            let barCount = scale.barCount(forLength: xValueChange, size: canvasSize)
            let lower = scaleX.lowerBound - barCount
            let upper = scaleX.upperBound + barCount
            if lower > 0, upper > 0, lower < upper, (upper - lower) >= 10 {
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
    
    private func updateScales(x: Range<Int>? = nil, y: Range<Double>? = nil) {
        if let x = x {
            var times: [String] = []
            let formatter = DateFormatter()
            var calendar = Foundation.Calendar(identifier: .gregorian)
            let timezone = TimeZone(identifier: "America/New_York")!
            calendar.timeZone = timezone
            formatter.calendar = calendar
            formatter.dateFormat = "HH:mm\ndd.MM.yy"
            formatter.timeZone = timezone
            
            var index = x.lowerBound
            while index < x.upperBound {
                guard index >= 0, data.count > index else { break }
                let date = Date(timeIntervalSince1970: data[index].timeOpen)
                times.append(formatter.string(from: date))
                index += scale.xGuideStep
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
    
    public func chartBackground(canvasOverlay: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void) -> ChartView {
        ChartView(
            interval: interval,
            data: data,
            scale: scaleOriginal,
            overlay: canvasOverlay,
            background: canvasBackground
        )
    }
    
    public func chartOverlay(canvasBackground: @escaping (_ context: inout GraphicsContext, _ scale: Scale, _ frame: CGRect) -> Void) -> ChartView {
        ChartView(
            interval: interval,
            data: data,
            scale: scaleOriginal,
            overlay: canvasOverlay,
            background: canvasBackground
        )
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView(interval: 60, data: [], scale: Scale())
    }
}

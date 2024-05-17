import SwiftUI
import TradingStrategy

struct CandleView: View {
    private let kline: Klines
    private let canvasSize: CGSize
    private let scale: CGPoint
    private var knotWidth: Double = 2
    
    private var color: Color {
        guard kline.body > 0 else { return .gray }
        return kline.isLong ? .green : .red
    }
    
    private var upperKnotHeight: Double {
        kline.upperWick / scale.y * canvasSize.height
    }
    
    private var bodyHeight: Double {
        let height = kline.body / scale.y * canvasSize.height
        guard height > 0 else { return 2 }
        return height
    }
    
    private var bottomKnotHeight: Double {
        kline.lowerWick / scale.y * canvasSize.height
    }
    
    private var bodyWidth: Double {
        kline.duration / scale.x * canvasSize.width * 0.9
    }

    init(kline: Klines, canvasSize: CGSize, scale: CGPoint) {
        self.kline = kline
        self.scale = scale
        self.canvasSize = canvasSize
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: bodyWidth / 5.0, height: Swift.max(0, upperKnotHeight))
            Rectangle()
                .fill(color)
                .frame(width: bodyWidth, height: max(0, bodyHeight))
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: bodyWidth / 5.0, height: Swift.max(0, bottomKnotHeight))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print(kline)
        }
    }
    
    // MARK: Modifiers

    func knotWidth(_ knotWidth: Double) -> Self {
        var view = self
        view.knotWidth = knotWidth
        return view
    }
}

struct CandleView_Previews: PreviewProvider {
    private struct Bar: Klines {
        var interval: TimeInterval = 60
        var timeOpen: TimeInterval = 0

        var priceOpen: Double = 110
        var priceHigh: Double = 105
        var priceLow: Double = 100
        var priceClose: Double = 95
    }

    static var previews: some View {
        CandleView(kline: Bar(), canvasSize: .init(width: 10, height: 100), scale: .init(x: 1, y: 1))
            .padding()
    }
}

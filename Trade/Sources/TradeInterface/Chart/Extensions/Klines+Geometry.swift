import Foundation
import TradingStrategy

extension Double {
    public func toPoint(
        atTime time: TimeInterval,
        scale: Scale,
        canvasSize size: CGSize
    ) -> CGPoint {
        let y = (Double(scale.y.upperBound) - self) / scale.amplitiude.height * size.height
        let x = (time - scale.x.lowerBound) / scale.amplitiude.width * size.width
        return .init(x: x, y: y)
    }
}

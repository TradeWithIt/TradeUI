import SwiftUI

extension CGPoint {
    fileprivate static func midPointForPoints(p1: CGPoint, p2: CGPoint) -> CGPoint {
        CGPoint(x:(p1.x + p2.x) / 2,y: (p1.y + p2.y) / 2)
    }
    
    fileprivate static func controlPointForPoints(p1: CGPoint, p2: CGPoint) -> CGPoint {
        var controlPoint = CGPoint.midPointForPoints(p1:p1, p2:p2)
        let diffY = abs(p2.y - controlPoint.y)
        
        if p1.y < p2.y {
            controlPoint.y += diffY
        } else if p1.y > p2.y {
            controlPoint.y -= diffY
        }
        return controlPoint
    }
}

extension Path {
    private static func height(points: [Double], canvas: CGSize) -> Double {
        var min: Double?
        var max: Double?
        
        if let minPoint = points.min(), let maxPoint = points.max(), minPoint != maxPoint {
            min = minPoint
            max = maxPoint
        } else {
            return 0
        }
        if let min = min, let max = max, min != max {
            if (min <= 0) {
                return canvas.height / Double(max - min)
            }else{
                return canvas.height / Double(max - min)
            }
        }
        return 0
    }

    static func linesWithPoints(points: [[CGPoint]], canvas: CGRect, color: Color) -> some View {
        ForEach(0..<points.count, id: \.self) { index in
            quadCurvedPathWithPoints(points: points[index], canvas: canvas, showPoints: false)
                .stroke(color)
        }
    }

    static func linesWithPoints(points: [[CGPoint]], canvas: CGRect) -> some View {
        ForEach(0..<points.count, id: \.self) { index in
            quadCurvedPathWithPoints(points: points[index], canvas: canvas, showPoints: false)
                .stroke(Color(hue: (Double(index) / Double(points.count) * 255.0) / 255.0, saturation: 1, brightness: 1))
        }
    }

    static func pathWithPoints(
        points: [CGPoint],
        canvas: CGRect,
        close: Bool = false,
        showPoints: Bool = false
    ) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        // Move to the starting point
        path.move(to: points[0])

        // Connect all points with straight lines
        for i in 1..<points.count {
            let p2 = points[i]
            path.addLine(to: p2) // Add a straight line to the next point

            // Optionally add circles to highlight points
            if showPoints {
                path.addEllipse(in: CGRect(x: p2.x - 4, y: p2.y - 4, width: 8, height: 8))
            }
        }

        // Optionally close the path by connecting to the canvas corner or the starting point
        if close {
            path.addLine(to: points[0]) // Close the path to the starting point
            path.closeSubpath()
        }

        return path
    }
    
    static func quadCurvedPathWithPoints(points: [CGPoint], canvas: CGRect, close: Bool = false, showPoints: Bool = false) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        var p1 = points[0]
        path.move(to: p1)
        for i in 1..<points.count {
            let p2 = points[i]
            let midPoint = CGPoint.midPointForPoints(p1: p1, p2: p2)
            path.addQuadCurve(to: midPoint, control: CGPoint.controlPointForPoints(p1: midPoint, p2: p1))
            path.addQuadCurve(to: p2, control: CGPoint.controlPointForPoints(p1: midPoint, p2: p2))
            if showPoints {
                path.addEllipse(in: CGRect(x: p2.x - 4, y: p2.y - 4, width: 8, height: 8))
            }
            p1 = p2
        }
        if close {
            path.addLine(to: .init(x: canvas.width, y: canvas.height))
            path.closeSubpath()
        }
        return path
    }
}

import SwiftUI

extension String {
    func removeTrailingZeros() -> String {
        let split = self.split(separator: ".")
        guard split.count == 2 else { return self }
        return "\(split.first ?? "").\(split.last?.prefix(4) ?? "0")"
    }
}

struct ScaleView<T: CustomStringConvertible & Hashable>: View {
    var orientation: Stack.Orientation = .vertical
    let labels: [T]

    var body: some View {
        GeometryReader { proxy in
            Stack.View(orientation: orientation, spacing: 0) {
                ForEach(labels, id: \.self) { label in
                    Text(label.description.removeTrailingZeros())
                }
                .minimumScaleFactor(0.01)
                .lineLimit(2)
                .frame(width: orientation == .horizontal ? proxy.size.width / CGFloat(max(labels.count, 1)) : proxy.size.width,
                       height: orientation == .vertical ? proxy.size.height / CGFloat(max(labels.count, 1)) : proxy.size.height)
            }
            .padding(.horizontal, proxy.size.width / 10)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}

struct ScaleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScaleView(orientation: .horizontal, labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(width: 60, height: 200)
            ScaleView(orientation: .horizontal, labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(height: 50)
            ScaleView(orientation: .horizontal, labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(height: 100)
        }
        
        Group {
            ScaleView(labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(width: 60, height: 200)
            ScaleView(labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(height: 50)
            ScaleView(labels: [70000, 60000, 50000, 40000, 30000, 20000])
                .frame(height: 100)
        }
    }
}

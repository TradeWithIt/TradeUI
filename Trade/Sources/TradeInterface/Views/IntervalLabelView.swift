import SwiftUI

extension TimeInterval {
    var intervalString: String {
        let minutes = self / 60
        if minutes < 1 {
            return "\(Int(self))s"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            return "\(Int(minutes / 60))h"
        }
    }
}

struct IntervalLabelView: View {
    let interval: TimeInterval
    var backgroundColor: Color = .clear
    
    var body: some View {
        Text(interval.intervalString)
            .font(.caption)
            .bold()
            .foregroundColor(.white)
            .padding(6)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding()
    }
}

#Preview {
    IntervalLabelView(interval: 300)
}

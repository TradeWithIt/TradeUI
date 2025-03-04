import SwiftUI

struct IntervalPickerView: View {
    @Binding var interval: TimeInterval
    var intervals: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600, 7200, 14400]
    
    var body: some View {
        VStack {
            Text("Select Interval").font(.headline)
            List(intervals, id: \..self) { intervalOption in
                Button(action: { interval = intervalOption }) {
                    Text(intervalLabel(for: intervalOption))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(minWidth: 200, minHeight: 250)
        .padding()
    }
    
    private func intervalLabel(for interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .hour]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "\(Int(interval))s"
    }
}

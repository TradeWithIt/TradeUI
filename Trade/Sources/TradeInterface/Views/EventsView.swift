import SwiftUI
import ForexFactory

struct EventsView: View {
    let events: [ForexEvent]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(events.sorted { $0.date > $1.date }, id: \.id) { event in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline)
                            
                            Text("\(event.country) • \(event.date)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Impact: \(event.impact.rawValue)")
                                .font(.footnote)
                                .foregroundColor(impactColor(event.impact))
                        }
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if let actual = event.actual {
                                Text("Actual: \(actual)")
                            }
                            if let forecast = event.forecast {
                                Text("Forecast: \(forecast)")
                            }
                            if let previous = event.previous {
                                Text("Previous: \(previous)")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    // Determine color based on impact
    private func impactColor(_ impact: Impact) -> Color {
        switch impact {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case .other: .gray
        }
    }
}

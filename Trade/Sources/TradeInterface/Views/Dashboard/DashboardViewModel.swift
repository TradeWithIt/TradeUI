import Foundation
import SwiftUI

extension DashboardView {
    @Observable class ViewModel {
        var symbol: String = ""
        var suggestedSearches: [Contract] = []
        
        private var isLookingUpSuggestions: Bool = false
        
        func suggestSearches() {
            guard !isLookingUpSuggestions else { return }
            isLookingUpSuggestions = true
            lookupSuggestions()
        }
        
        func formatCandleTimeInterval(_ interval: TimeInterval) -> String {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated

            switch interval {
            case 60...3599:  // Seconds to less than an hour
                formatter.allowedUnits = [.minute]
            case 3600...86399:  // One hour to less than a day
                formatter.allowedUnits = [.hour]
            case 86400...604799:  // One day to less than a week
                formatter.allowedUnits = [.day]
            case 604800...:  // One week and more
                formatter.allowedUnits = [.weekOfMonth]
            default:
                formatter.allowedUnits = [.second]  // For less than a minute
            }

            return formatter.string(from: interval) ?? "N/A"
        }
        
        private func lookupSuggestions() {
            let symbolToSearch = symbol
            Task {
                do {
                    suggestedSearches = try await suggestContract(symbol) ?? []
                    if symbolToSearch != symbol {
                        lookupSuggestions()
                    } else {
                        isLookingUpSuggestions = false
                    }
                } catch {
                    print("🔴 Failed to suggest search with error: ", error)
                }
            }
        }
    
        private func suggestContract(_ symbol: String) async throws -> [Contract]? {
            return nil
        }
    }
}

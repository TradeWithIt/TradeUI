import Foundation
import SwiftUI
import Combine
import Brokerage

extension DashboardView {
    @Observable class ViewModel {
        var cancellables = Set<AnyCancellable>()
        var symbol: String = ""
        var suggestedSearches: [Product] = []
        
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
        
        private func suggestSearches() {
            do {
                try loadProducts(symbol: symbol)
            } catch {
                print("🔴 Failed to suggest search with error: ", error)
            }
        }
        
        private func loadProducts(symbol: Symbol) throws {
            try Product.fetchProducts(symbol: symbol)
                .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: false)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("🔴 errorMessage: ", error)
                    }
                }, receiveValue: { response in
                    self.suggestedSearches = Array(response.products)
                })
                .store(in: &cancellables)
        }
    
        private func suggestContract(_ symbol: String) async throws -> [String]? {
            return nil
        }
    }
}

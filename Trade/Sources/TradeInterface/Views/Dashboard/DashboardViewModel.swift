import Foundation
import SwiftUI
import Combine
import Brokerage

class ObservableString {
    // The subject that will manage the updates
    private let subject = CurrentValueSubject<String, Never>("")
    
    // The public publisher that external subscribers can subscribe to
    var publisher: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }
    
    // The property that you will update
    var value: String {
        didSet {
            subject.send(value)
        }
    }
    
    init(initialValue: String) {
        self.value = initialValue
    }
}

extension DashboardView {
    @Observable class ViewModel {
        var cancellables = Set<AnyCancellable>()
        var symbol = ObservableString(initialValue: "")
        var suggestedSearches: [any Contract] = []
        
        private var marketData: MarketData?
        
        deinit {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        
        init() {
            symbol.publisher
                .removeDuplicates()
                .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] symbol in
                    guard let self, let marketData = self.marketData else { return }
                    do {
                        try self.loadProducts(marketData: marketData, symbol: Symbol(symbol))
                    } catch {
                        print("🔴 Failed to suggest search with error: ", error)
                    }
                }
                .store(in: &cancellables)
        }
        
        func updateMarketData(_ marketData: MarketData) {
            self.marketData = marketData
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
        
        private func loadProducts(marketData: MarketData, symbol: Symbol) throws {
            try marketData.search(nameOrSymbol: symbol)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("🔴 errorMessage: ", error)
                    }
                }, receiveValue: { response in
                    self.suggestedSearches = response
                })
                .store(in: &cancellables)
        }
    }
}

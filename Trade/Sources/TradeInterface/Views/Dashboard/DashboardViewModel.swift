import Foundation
import SwiftUI
import Combine
import Brokerage
import Runtime

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
        enum SidebarTab: String, CaseIterable {
            case watchers = "Account"
            case localFiles = "Local Files"

            var icon: String {
                switch self {
                case .watchers: return "case.fill"
                case .localFiles: return "folder"
                }
            }
        }
        
        private var cancellables = Set<AnyCancellable>()
        var symbol = ObservableString(initialValue: "")
        var suggestedSearches: [any Contract] = []
        var selectedTab: SidebarTab = .watchers
        
        private var market: Market?
        
        deinit {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        
        init() {
            symbol.publisher
                .removeDuplicates()
                .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] symbol in
                    guard let self, let market = self.market else { return }
                    do {
                        try self.loadProducts(market: market, symbol: Symbol(symbol))
                    } catch {
                        print("🔴 Failed to suggest search with error: ", error)
                    }
                }
                .store(in: &cancellables)
        }
        
        func updateMarketData(_ market: Market) {
            self.market = market
        }
        
        private func loadProducts(market: MarketSearch, symbol: Symbol) throws {
            try market.search(nameOrSymbol: symbol)
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

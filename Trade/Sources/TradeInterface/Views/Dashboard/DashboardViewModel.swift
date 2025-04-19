import Foundation
import SwiftUI
import Combine
import Brokerage
import Runtime
import TradingStrategy
import ForexFactory

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
        var events: [ForexEvent] = []
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
        
        @MainActor func chooseStrategyFolder(registry: StrategyRegistry) -> Bool {
            let dialog = NSOpenPanel()
            dialog.title = "Choose Strategy Folder"
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false
            dialog.allowsMultipleSelection = false

            if dialog.runModal() == .OK, let url = dialog.url {
                UserDefaults.standard.set(url.path, forKey: "StrategyFolderPath")
                return true
            }
            return false
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
        
        @MainActor
        func loadForexEvents() async -> [ForexEvent] {
            let cacheKey = "forexEventsCache"
            let lastFetchKey = "forexEventsLastFetch"
            
            // Check UserDefaults for cached events
            if let savedData = UserDefaults.standard.data(forKey: cacheKey),
               let lastFetchDate = UserDefaults.standard.object(forKey: lastFetchKey) as? Date,
               Calendar.current.isDateInToday(lastFetchDate) {
                
                do {
                    let cachedEvents = try JSONDecoder().decode([ForexEvent].self, from: savedData)
                    events = cachedEvents
                    print("✅ Loaded cached Forex events from UserDefaults.")
                    return cachedEvents
                } catch {
                    print("⚠️ Failed to decode cached Forex events, fetching new data.")
                }
            }

            // Fetch new data if no valid cache exists
            do {
                let newEvents = try await ForexAPI
                    .fetchEvents()
                    .eventsForToday()
                    .events(by: "USD")
                
                // Update the UI
                events = newEvents
                
                // Cache the new data
                let encodedData = try JSONEncoder().encode(newEvents)
                UserDefaults.standard.set(encodedData, forKey: cacheKey)
                UserDefaults.standard.set(Date(), forKey: lastFetchKey)

                print("✅ Fetched new Forex events and cached them.")
                return newEvents
            } catch {
                print("🔴 Failure fetching forex events:", error)
            }
            return []
        }
    }
}

// MARK: Types

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

extension ForexEvent: TradingStrategy.Annoucment {
    public var timestamp: TimeInterval {
        date.timeIntervalSince1970
    }
    
    public var annoucmentImpact: TradingStrategy.AnnoucmentImpact {
        switch impact {
        case .high: .high
        case .medium: .medium
        case .low: .low
        case .other: .low
        }
    }
}

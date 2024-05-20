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
    enum SheetType {
        case snapshotPreview
        case snapshotPlayback
    }
    @Observable class ViewModel {
        var cancellables = Set<AnyCancellable>()
        var symbol = ObservableString(initialValue: "")
        var suggestedSearches: [any Contract] = []
        var snapshotFileNames: [String] = []
        
        var selectedSnapshot: String? = nil
        var isPresentingSgeet: SheetType? = nil
        
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
        
        func loadSnapshotFileNames(url: URL?, fileManager: FileManager = .default) {
            guard let url = url else { return }
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                snapshotFileNames = fileURLs.compactMap { url in
                    print(url, url.pathExtension)
                    return url.pathExtension == "txt" ? url.deletingPathExtension().lastPathComponent : nil
                }
            } catch {
                print("Error loading files: \(error)")
            }
        }
        
        func saveHistoryToFile(symbol: Symbol, interval: TimeInterval, fileProvider: MarketDataFileProvider) throws {
            let calendar = Calendar.current
            let timeZone = TimeZone.current

            // Set up date components for the start of April 2024
            var startDateComponents = DateComponents()
            startDateComponents.year = 2024
            startDateComponents.month = 4
            startDateComponents.day = 1
            startDateComponents.timeZone = timeZone

            // Create the start date
            let startDate = calendar.date(from: startDateComponents)!
            try market?.marketDataSnapshot(
                symbol: symbol,
                interval: interval,
                userInfo: [MarketDataKey.bufferInfo.rawValue: -startDate.timeIntervalSinceNow]
            )
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("🔴 errorMessage: ", error)
                }
                print("saved history snapshot to file")
            }, receiveValue: { candleData in
                do {
                    print("Saving data to file:", candleData.bars.count)
                    try fileProvider.save(symbol: candleData.symbol, interval: candleData.interval, bars: candleData.bars, strategyName: "")
                } catch {
                    print("Something went wrong", error)
                }
            })
            .store(in: &cancellables)
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

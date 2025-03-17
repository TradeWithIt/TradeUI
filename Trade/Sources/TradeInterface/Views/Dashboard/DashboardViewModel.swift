import Foundation
import SwiftUI
import Combine
import Brokerage
import Runtime
import TradingStrategy

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
        
        @MainActor func chooseStrategyFolder(registry: StrategyRegistry) {
            let dialog = NSOpenPanel()
            dialog.title = "Choose Strategy Folder"
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false
            dialog.allowsMultipleSelection = false

            if dialog.runModal() == .OK, let url = dialog.url {
                UserDefaults.standard.set(url.path, forKey: "StrategyFolderPath")
                loadAllUserStrategies(into: registry)
            }
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

        // MARK: Load Dylibs Files and its Strategies
        
        func loadAvailableStrategies(from path: String) -> [String] {
            let handle = dlopen(path, RTLD_NOW)
            guard handle != nil else {
                print("❌ Failed to open \(path)")
                return []
            }

            guard let symbol = dlsym(handle, "getAvailableStrategies") else {
                print("❌ Failed to find `getAvailableStrategies` symbol in \(path)")
                return []
            }

            typealias GetAvailableStrategiesFunc = @convention(c) () -> UnsafePointer<CChar>
            let function = unsafeBitCast(symbol, to: GetAvailableStrategiesFunc.self)

            let strategyPointer = function()
            let strategyList = String(cString: strategyPointer)

            free(UnsafeMutablePointer(mutating: strategyPointer))

            return strategyList.components(separatedBy: ",")
        }

        func loadStrategy(from path: String, strategyName: String) -> Strategy.Type? {
            let handle = dlopen(path, RTLD_NOW)
            guard handle != nil else {
                print("❌ Failed to open \(path): \(String(cString: dlerror()!))")
                return nil
            }

            guard let symbol = dlsym(handle, "createStrategy") else {
                print("❌ Failed to find `createStrategy` symbol in \(path): \(String(cString: dlerror()!))")
                return nil
            }

            typealias CreateStrategyFunc = @convention(c) (UnsafePointer<CChar>) -> UnsafeRawPointer?
            let function = unsafeBitCast(symbol, to: CreateStrategyFunc.self)
            guard let strategyPointer = function(strategyName) else {
                print("❌ `createStrategy()` returned nil")
                return nil
            }

            let factoryBox = Unmanaged<Box<() -> Strategy>>.fromOpaque(strategyPointer).takeRetainedValue()
            let strategyInstance = factoryBox.value()
            let strategyType = type(of: strategyInstance)
            return strategyType
        }

        @MainActor
        func loadAllUserStrategies(into registry: StrategyRegistry) {
            guard let strategyFolder = UserDefaults.standard.string(forKey: "StrategyFolderPath") else {
                print("⚠️ No strategy folder set in UserDefaults.")
                return
            }

            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(atPath: strategyFolder) else {
                return
            }

            for file in files where file.hasSuffix(".dylib") {
                let fullPath = (strategyFolder as NSString).appendingPathComponent(file)

                let strategyNames = loadAvailableStrategies(from: fullPath)

                for strategyName in strategyNames {
                    if let strategyType = loadStrategy(from: fullPath, strategyName: strategyName) {
                        registry.register(strategyType: strategyType, name: strategyName)
                        print("✅ Successfully registered strategy: \(strategyName)")
                    } else {
                        print("❌ Failed to load strategy: \(strategyName)")
                    }
                }
            }
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

private final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}


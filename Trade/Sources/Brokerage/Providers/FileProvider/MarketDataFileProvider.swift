import Foundation
import Combine

public final class MarketDataFileProvider: @unchecked Sendable, MarketData {
    public enum Error: Swift.Error, LocalizedError {
        case missingDirectory(String)
        case missingFile(String)
        case wrongFileFormat(String)
    }
    
    public let snapshotsDirectory: URL?
    private var activeSubscriptions: [MarketDataFile] = []
    public var account: Account? = nil
    
    deinit {
        activeSubscriptions.forEach { $0.close() }
        activeSubscriptions.removeAll()
    }
    
    required public init() {
        let fileManager = FileManager.default
        var directory: URL? = nil
        do {
            directory = try fileManager.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            print("Error reading file: \(error)")
        }
        snapshotsDirectory = directory?.appendingPathComponent("Snapshots")
    }
    
    public func pull(url: URL) {
        guard let file = activeSubscriptions.first(where: { $0.fileUrl == url }) else {
            return
        }
        Task {
            try await Task.sleep(for: .milliseconds(5))
            file.publish()
        }
    }
    
    public func connect() throws {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileManager = FileManager.default
        // Check if the Snapshots directory exists, if not throw an error
        guard fileManager.fileExists(atPath: snapshotsDirectory.path) else {
            throw Error.missingDirectory("Missing 'Snapshots' directory.")
        }
    }
    
    public func save(symbol: Symbol, interval: TimeInterval, bars: [Bar], strategyName strategy: String) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy_HH-mm-ss"
        let fileName = "\(symbol)-\(interval)_\(dateFormatter.string(from: Date()))"
        let marketDataFile = try marketDataFile(marketDataFileURL(fileName))
        marketDataFile.save(
            strategyName: strategy,
            candleData: CandleData(symbol: symbol, interval: interval, bars: bars)
        )
    }
    
    public func loadFile(url: URL) throws -> CandleData? {
        let marketDataFile = try marketDataFile(url)
        return marketDataFile.loadCandleData()
    }
    
    public func loadFileData(url: URL, symbol: Symbol, interval: TimeInterval) throws -> CandleData? {
        let marketDataFile = try marketDataFile(url)
        return marketDataFile.loadCandleData()
    }
    
    public func unsubscribeMarketData(contract: any Contract, interval: TimeInterval) {
        activeSubscriptions.removeAll(where: {
            let shouldRemove = $0.fileUrl.lastPathComponent.contains("\(contract.symbol)")
            if shouldRemove { $0.close() }
            return shouldRemove
        })
    }
    
    public func quotePublisher(contract product: any Contract) throws -> AnyPublisher<Quote, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    public func marketDataSnapshot(
        contract product: any Contract,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date? = nil,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        guard let url = userInfo[MarketDataKey.snapshotFileURL.rawValue] as? URL else {
            throw Error.missingFile("File URL missing in user info")
        }
        let mockCandleData = try loadFileData(url: url, symbol: product.symbol, interval: interval)
        return Just(mockCandleData ?? CandleData(
            symbol: product.symbol,
            interval: interval,
            bars: []
        ))
            .eraseToAnyPublisher()
    }
    
    public func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        guard let fileURL = userInfo[MarketDataKey.snapshotFileURL.rawValue] as? URL else {
            throw Error.missingFile("File URL missing in user info")
        }
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            throw Error.missingFile("File \(fileURL.lastPathComponent) not found.")
        }
        
        let marketDataFile = try marketDataFile(fileURL)
        activeSubscriptions.append(marketDataFile)
        return try marketDataFile.readBars(
            symbol: product.symbol,
            interval: interval,
            loadAllAtOnce: false
        )
    }
    
    public func tradingHour(_ product: any Contract) async throws -> [TradingHour] { return [] }
    
    private func marketDataFile(_ url: URL) throws -> MarketDataFile {
        if let file = activeSubscriptions.first(where: { $0.fileUrl == url }) {
            return file
        }
        var url = url
        let marketDataFile: MarketDataFile
        switch url.pathExtension {
        case "txt":
            marketDataFile = KlineMarketDataFile(fileUrl: url)
        case "csv":
            marketDataFile = CSVMarketDataFile(fileUrl: url)
        default:
            url.appendPathExtension("txt")
            marketDataFile = KlineMarketDataFile(fileUrl: url)
        }
        return marketDataFile
    }
    
    private func marketDataFileURL(_ name: String) throws -> URL {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        var fileURL = snapshotsDirectory.appendingPathComponent(name)
        switch fileURL.pathExtension {
        case "txt": break
        case "csv": break
        default:
            fileURL.appendPathExtension("txt")
        }
        return fileURL
    }
}

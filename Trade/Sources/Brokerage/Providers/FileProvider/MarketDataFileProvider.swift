import Foundation
import Combine

public class MarketDataFileProvider: MarketData {
    public enum Error: Swift.Error, LocalizedError {
        case missingDirectory(String)
        case missingFile(String)
        case wrongFileFormat(String)
    }
    
    public private(set) var snapshotsDirectory: URL?
    private var activeSubscriptions: [MarketDataFile] = []
    
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
        let marketDataFile = try marketDataFile(fileName)
        marketDataFile.save(
            strategyName: strategy,
            candleData: CandleData(symbol: symbol, interval: interval, bars: bars)
        )
    }
    
    public func loadFile(name: String) throws -> CandleData? {
        let marketDataFile = try marketDataFile(name)
        return marketDataFile.loadCandleData()
    }
    
    public func loadFileData(forSymbol symbol: Symbol, interval: TimeInterval, fileName: String) throws -> CandleData? {
        let marketDataFile = try marketDataFile(fileName)
        return marketDataFile.loadCandleData()
    }
    
    public func unsubscribeMarketData(symbol: Symbol, interval: TimeInterval) {
        activeSubscriptions.removeAll(where: {
            let path = $0.fileUrl.lastPathComponent
            return path.contains("\(symbol)-\(interval)")
        })
    }
    
    public func marketData(symbol: Symbol, interval: TimeInterval, userInfo: [String: Any]) throws -> AnyPublisher<CandleData, Never> {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileName = userInfo[MarketDataKey.snapshotFileName.rawValue] as? String ?? ""
        let playbackSpeed = userInfo[MarketDataKey.snapshotPlaybackSpeedInfo.rawValue] as? Double ?? 1
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = try marketDataFile(fileName)
        activeSubscriptions.append(marketDataFile)
        return try marketDataFile.readBars(
            symbol: symbol,
            interval: interval,
            speedFactor: playbackSpeed,
            loadAllAtOnce: false
        )
    }
    
    public func marketDataSnapshot(
        symbol:  Symbol,
        type: String,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date? = nil,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let fileName = userInfo[MarketDataKey.snapshotFileName.rawValue] as? String ?? ""
        let mockCandleData = try loadFileData(
            forSymbol: symbol,
            interval: interval,
            fileName: fileName
        )
        return Just(mockCandleData ?? CandleData(
            symbol: symbol,
            interval: interval,
            bars: []
        ))
            .eraseToAnyPublisher()
    }
    
    public func marketDataSnapshot(
        contract product: any Contract,
        type: String,
        interval: TimeInterval,
        startDate: Date,
        endDate: Date? = nil,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let fileName = userInfo[MarketDataKey.snapshotFileName.rawValue] as? String ?? ""
        let mockCandleData = try loadFileData(
            forSymbol: product.symbol,
            interval: interval,
            fileName: fileName
        )
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
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileName = userInfo[MarketDataKey.snapshotFileName.rawValue] as? String ?? ""
        let playbackSpeed = userInfo[MarketDataKey.snapshotPlaybackSpeedInfo.rawValue] as? Double ?? 1
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = try marketDataFile(fileName)
        activeSubscriptions.append(marketDataFile)
        return try marketDataFile.readBars(
            symbol: product.symbol,
            interval: interval,
            speedFactor: playbackSpeed,
            loadAllAtOnce: false
        )
    }
    
    private func marketDataFile(_ name: String) throws -> MarketDataFile {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        var fileURL = snapshotsDirectory.appendingPathComponent(name)
        let marketDataFile: MarketDataFile
        switch fileURL.pathExtension {
        case "txt":
            marketDataFile = KlineMarketDataFile(fileUrl: fileURL)
        case "csv":
            marketDataFile = CSVMarketDataFile(fileUrl: fileURL)
        default:
            fileURL.appendPathExtension("txt")
            marketDataFile = KlineMarketDataFile(fileUrl: fileURL)
        }
        return marketDataFile
    }
}

import Foundation
import Combine

public class MarketDataFileProvider: MarketData {
    public enum Error: Swift.Error, LocalizedError {
        case missingDirectory(String)
        case missingFile(String)
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
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy_HH-mm-ss"
        let fileName = "\(symbol)-\(interval)_\(dateFormatter.string(from: Date()))"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        marketDataFile.save(
            strategyName: strategy,
            candleData: CandleData(symbol: symbol, interval: interval, bars: bars)
        )
    }
    
    public func loadFile(name: String) throws -> CandleData? {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileURL = snapshotsDirectory.appendingPathComponent(name + ".txt")
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        return marketDataFile.loadCandleData()
    }
    
    public func loadFileData(forSymbol symbol: Symbol, interval: TimeInterval, snapshot: Date) throws -> CandleData? {
        guard let snapshotsDirectory else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy_HH-mm-ss"
        
        let fileName = "\(symbol)-\(interval)_\(dateFormatter.string(from: Date()))"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
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
        
        let snapshotDate = userInfo[MarketDataKey.snapshotDateInfo.rawValue] as? Date ?? Date()
        let playbackSpeed = userInfo[MarketDataKey.snapshotPlaybackSpeedInfo.rawValue] as? Double ?? 1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy_HH-mm-ss"
        
        let fileName = "\(symbol)-\(interval)_\(dateFormatter.string(from: snapshotDate))"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
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
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let snapshotDate = userInfo[MarketDataKey.snapshotDateInfo.rawValue] as? Date ?? Date()
        let mockCandleData = try loadFileData(
            forSymbol: symbol,
            interval: interval,
            snapshot: snapshotDate
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
        interval: TimeInterval,
        userInfo: [String: Any]
    ) throws -> AnyPublisher<CandleData, Never> {
        let snapshotDate = userInfo[MarketDataKey.snapshotDateInfo.rawValue] as? Date ?? Date()
        let mockCandleData = try loadFileData(
            forSymbol: product.symbol,
            interval: interval,
            snapshot: snapshotDate
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
        
        let snapshotDate = userInfo[MarketDataKey.snapshotDateInfo.rawValue] as? Date ?? Date()
        let playbackSpeed = userInfo[MarketDataKey.snapshotPlaybackSpeedInfo.rawValue] as? Double ?? 1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yyyy_HH-mm-ss"
        
        let fileName = "\(product.symbol)-\(interval)_\(dateFormatter.string(from: snapshotDate))"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        activeSubscriptions.append(marketDataFile)
        return try marketDataFile.readBars(
            symbol: product.symbol,
            interval: interval,
            speedFactor: playbackSpeed,
            loadAllAtOnce: false
        )
    }
}

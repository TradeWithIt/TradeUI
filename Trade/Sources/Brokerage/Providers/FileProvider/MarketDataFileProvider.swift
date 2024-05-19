import Foundation
import Combine

import Foundation
import Combine

public class MarketDataFileProvider: MarketData {
    public enum Error: Swift.Error, LocalizedError {
        case missingDirectory(String)
        case missingFile(String)
    }
    
    public private(set) var snapshotsDirectory: URL!
    
    required public init() {
        let fileManager = FileManager.default
        let directory = try? fileManager.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        snapshotsDirectory = directory?.appendingPathComponent("Snapshots")
    }
    
    public func connect() throws {
        guard snapshotsDirectory != nil else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileManager = FileManager.default
        // Check if the Snapshots directory exists, if not throw an error
        guard fileManager.fileExists(atPath: snapshotsDirectory.path) else {
            throw Error.missingDirectory("Missing 'Snapshots' directory.")
        }
    }
    
    public func save(symbol: Symbol, interval: TimeInterval, bars: [Bar]) {
        let fileName = "\(symbol):\(interval)"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        marketDataFile.save(
            candleData: CandleData(symbol: symbol, interval: interval, bars: bars)
        )
    }
    
    public func unsubscribeMarketData(symbol: Symbol, interval: TimeInterval) {
        assertionFailure("unsubscribe from market data, doesn't work for files.")
    }
    
    public func marketData(symbol: Symbol, interval: TimeInterval, buffer: TimeInterval) throws -> AnyPublisher<CandleData, Never> {
        guard snapshotsDirectory != nil else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileName = "\(symbol):\(interval)"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        return try marketDataFile.readBars(
            symbol: symbol,
            interval: interval,
            speedFactor: buffer,
            loadAllAtOnce: false
        )
    }
    
    public func marketData(
        contract product: any Contract,
        interval: TimeInterval,
        buffer: TimeInterval
    ) throws -> AnyPublisher<CandleData, Never> {
        guard snapshotsDirectory != nil else {
            throw Error.missingDirectory("Failed to initiate directory.")
        }
        
        let fileName = "\(product.symbol):\(interval)"
        let fileURL = snapshotsDirectory.appendingPathComponent(fileName + ".txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Error.missingFile("File \(fileName) not found.")
        }
        
        let marketDataFile = MarketDataFile(fileUrl: fileURL)
        return try marketDataFile.readBars(
            symbol: product.symbol,
            interval: interval,
            speedFactor: buffer,
            loadAllAtOnce: false
        )
    }
}

import Foundation
import Combine

public final class KlineMarketDataFile: @unchecked Sendable, MarketDataFile {
    public let fileUrl: URL
    private let subject = PassthroughSubject<CandleData, Never>()
    private var fileHandle: FileHandle?
    private var symbol: String = ""
    private var barInterval: TimeInterval = 0
    
    public init(fileUrl: URL) {
        self.fileUrl = fileUrl
    }
    
    public func close() {
        fileHandle?.closeFile()
        fileHandle = nil
        subject.send(completion: .finished)
    }
    
    public func publish() {
        guard let fileHandle = fileHandle else { return }
        if let lineData = fileHandle.readLine() {
            let decoder = JSONDecoder()
            if let bar = try? decoder.decode(Bar.self, from: lineData) {
                subject.send(CandleData(symbol: symbol, interval: barInterval, bars: [bar]))
            }
        } else {
            fileHandle.closeFile()
            self.fileHandle = nil
            subject.send(completion: .finished)
        }
    }
    
    public func readBars(
        symbol: Symbol,
        interval: TimeInterval,
        loadAllAtOnce: Bool = false
    ) throws -> AnyPublisher<CandleData, Never> {
        self.fileHandle?.closeFile()
        self.fileHandle = try FileHandle(forReadingFrom: fileUrl)
        self.symbol = fileHandle?.readLine()?.toString() ?? ""
        self.barInterval = TimeInterval(fileHandle?.readLine()?.toString() ?? "0") ?? 0
        _ = fileHandle?.readLine()?.toString() // strategyName
        
        if loadAllAtOnce {
            if let data = loadCandleData() {
                subject.send(data)
            }
            subject.send(completion: .finished)
        } else {
            Task {
                try await Task.sleep(for: .milliseconds(200))
                await MainActor.run { publish() }
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    public func save(strategyName: String, candleData: CandleData) {
        let fileManager = FileManager.default
        let encoder = JSONEncoder()
        let filePath = fileUrl.path(percentEncoded: false)
        do {
            if !fileManager.fileExists(atPath: filePath) {
                // Create intermediate directories
                try fileManager.createDirectory(at: fileUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                // Create new file
                fileManager.createFile(atPath: filePath, contents: nil)
            }
            
            let existingData = try String(contentsOf: fileUrl, encoding: .utf8)
            var lines = existingData.components(separatedBy: .newlines)
            
            if lines.count > 3 {
                let currentSymbol = lines[0]
                let currentInterval = TimeInterval(lines[1]) ?? 0
                // let currentStrategy = lines[2]
                
                if currentSymbol == candleData.symbol && currentInterval == candleData.interval {
                    // Append new bars if symbol and interval match
                    let newBars = try candleData.bars.map { try encoder.encode($0) }
                    lines.append(contentsOf: newBars.map { String(data: $0, encoding: .utf8) ?? "" })
                } else {
                    // Replace file content if symbol or interval don't match
                    lines = [
                        candleData.symbol,
                        String(candleData.interval)
                    ]
                    lines.append(
                        contentsOf: try  candleData.bars.map { String(data: try encoder.encode($0), encoding: .utf8) ?? "" }
                    )
                }
            } else {
                // Initialize file with new content
                lines = [
                    candleData.symbol,
                    String(candleData.interval),
                    strategyName
                ]
                lines.append(
                    contentsOf: try  candleData.bars.map { String(data: try encoder.encode($0), encoding: .utf8) ?? "" }
                )
            }
            
            try lines.joined(separator: "\n").write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save or update the file: \(error)")
        }
    }
    
    public func loadCandleData() -> CandleData? {
        do {
            let content = try String(contentsOfFile: fileUrl.path(percentEncoded: false), encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            guard lines.count > 3,
                  let interval = TimeInterval(lines[1]) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let bars = lines.dropFirst(3).compactMap { line -> Bar? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(Bar.self, from: data)
            }
            
            return CandleData(symbol: lines[0], interval: interval, bars: bars)
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }
}

extension Data {
    /// Converts the data to a string using the specified encoding.
    /// - Parameter encoding: The string encoding to use. The default is `.utf8`.
    /// - Returns: A string representation of the data if conversion is successful, otherwise nil.
    func toString(using encoding: String.Encoding = .utf8) -> String? {
        return String(data: self, encoding: encoding)
    }
}

extension FileHandle {
    func readLine() -> Data? {
        var data = Data()
        while true {
            let tempData = self.readData(ofLength: 1)
            if tempData.isEmpty {
                return data.isEmpty ? nil : data
            }
            if tempData[0] == 10 {
                break
            }
            data.append(tempData)
        }
        return data.isEmpty ? nil : data
    }
}

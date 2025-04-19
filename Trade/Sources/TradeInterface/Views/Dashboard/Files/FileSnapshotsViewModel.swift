import Foundation
import SwiftUI
import Combine
import Brokerage
import Runtime

extension FileSnapshotsView {
    public struct FileNode: Sendable, Identifiable, Hashable, Codable {
        public var id = UUID()
        public let name: String
        public let url: URL
        public let isDirectory: Bool
        var children: [FileNode]?
    }
    
    @Observable public class ViewModel: @unchecked Sendable {
        public struct SnapshotPreview: Hashable, Codable {
            public let file: FileNode
        }
        public struct SnapshotPlayback: Hashable, Codable {
            public let file: FileNode
        }
        public enum PresentedSheetType {
            case snapshotPreview(node: FileNode)
            case snapshotPlayback(node: FileNode)
            
            public var node: FileNode {
                switch self {
                case let .snapshotPreview(node): node
                case let .snapshotPlayback(node): node
                }
            }
        }
        
        private var cancellables = Set<AnyCancellable>()
        var fileTree: [FileNode] = []
        var isPresentingSheet: PresentedSheetType? = nil
        var selectedSnapshot: FileNode? {
            switch isPresentingSheet {
            case .snapshotPreview(let node): node
            case .snapshotPlayback(let node): node
            case nil: nil
            }
        }
        
        /// 📂 Loads file structure into a hierarchical format
        func loadFileTree(url: URL?) {
            guard let url else { return }
            Task {
                let root = self.buildFileTree(at: url)
                await MainActor.run {
                    self.fileTree = [root]
                }
            }
        }
        
        private func buildFileTree(at url: URL) -> FileNode {
            let fileManager = FileManager.default
            var children: [FileNode] = []
            
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) {
                for content in contents {
                    let resourceValues = try? content.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let fileName = content.lastPathComponent
                    guard !fileName.hasPrefix(".") else { continue }
                    
                    if isDirectory {
                        let subTree = buildFileTree(at: content)
                        if let subChildren = subTree.children, !subChildren.isEmpty {
                            children.append(subTree)
                        }
                    } else if fileName.hasSuffix(".txt") || fileName.hasSuffix(".csv") {
                        children.append(FileNode(name: fileName, url: content, isDirectory: false, children: nil))
                    }
                }
            }
            return FileNode(name: url.lastPathComponent, url: url, isDirectory: true, children: children.isEmpty ? nil : children)
        }
        
        deinit {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        
        func saveHistoryToFile(
            contract: any Contract,
            interval: TimeInterval,
            market: Market?,
            fileProvider: MarketDataFileProvider
        ) throws {
            let calendar = Calendar.current
            let timeZone = TimeZone.current

            // Set up date components for the start
            var startDateComponents = DateComponents()
            startDateComponents.year = 2024
            startDateComponents.month = 11
            startDateComponents.day = 6
            startDateComponents.timeZone = timeZone
            // Create the start date
            let startDate = calendar.date(from: startDateComponents)!
            
            // Set up date components for the end
            var endDateComponents = DateComponents()
            endDateComponents.year = 2024
            endDateComponents.month = 11
            endDateComponents.day = 8
            endDateComponents.timeZone = timeZone
            // Create the end date
            let endDate = calendar.date(from: endDateComponents)!
            
            try market?.marketDataSnapshot(
                contract: contract,
                interval: interval,
                startDate: startDate,
                endDate: endDate,
                userInfo: [:]
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
    }
}

import Foundation
import SwiftUI
import Combine
import Brokerage
import Runtime

extension FileSnapshotsView {
    @Observable public class ViewModel {
        public struct SnapshotPreview: Hashable, Codable {
            public let fileName: String
        }
        public struct SnapshotPlayback: Hashable, Codable {
            public let fileName: String
        }
        public enum PresentedSheetType {
            case snapshotPreview(fileName: String)
            case snapshotPlayback(fileName: String)
            
            public var fileName: String {
                switch self {
                case let .snapshotPreview(fileName): fileName
                case let .snapshotPlayback(fileName): fileName
                }
            }
        }
        
        private var cancellables = Set<AnyCancellable>()
        var snapshotFileNames: [String] = []
        var isPresentingSheet: PresentedSheetType? = nil
        var selectedSnapshot: String? {
            switch isPresentingSheet {
            case .snapshotPreview(let fileName): fileName
            case .snapshotPlayback(let fileName): fileName
            case nil: nil
            }
        }
        
        deinit {
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        
        func loadSnapshotFileNames(url: URL?, fileManager: FileManager = .default) {
            guard let url = url else { return }
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                snapshotFileNames = fileURLs.compactMap { url in
                    print(url, url.pathExtension)
                    return ["txt", "csv"].contains(url.pathExtension) ? url.lastPathComponent : nil
                }
            } catch {
                print("Error loading files: \(error)")
            }
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

import Foundation

extension OrderView {
    @Observable class ViewModel {
        var orders: [String] = []
        var positions: [String] = []
        
        func orders() async throws -> [String]? {
            return nil
        }
        
        func positions() async throws -> [String]? {
            return nil
        }
    }
}

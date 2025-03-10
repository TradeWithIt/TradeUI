import Foundation
import SwiftUI

public struct DebounceViewModifier<V: Equatable>: ViewModifier {
    @State private var debounceTask: Task<Void, Never>? = nil

    let value: V
    let initial: Bool
    let interval: ContinuousClock.Instant.Duration
    let action: () -> Void

    public init(value: V, initial: Bool, interval: ContinuousClock.Instant.Duration, action: @escaping () -> Void) {
        self.value = value
        self.initial = initial
        self.interval = interval
        self.action = action
    }

    public func body(content: Content) -> some View {
        content
            .onChange(of: value) {
                debounceTask?.cancel()
                debounceTask = Task {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: interval)
                    
                    guard !Task.isCancelled else { return }
                    await MainActor.run { action() }
                }
            }
    }
}

extension View {
    @inlinable
    func onChangeDebounced<V>(
        of value: V,
        initial: Bool = false,
        interval: ContinuousClock.Instant.Duration = .milliseconds(250),
        perform action: @escaping () -> Void
    ) -> some View where V: Equatable {
        modifier(DebounceViewModifier(value: value, initial: initial, interval: interval, action: action))
    }
}

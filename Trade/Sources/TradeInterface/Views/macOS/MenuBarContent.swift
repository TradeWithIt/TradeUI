import SwiftUI

#if os(macOS)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

public struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(TradeManager.self) private var trades
    @AppStorage("activationPolicy") var activationPolicy: NSApplication.ActivationPolicy = .regular
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var isRegularActivationPolicy: Bool {
        activationPolicy == .regular
    }
    
    public init() {}
    
    public var body: some View {
        accessory
            .onAppear {
                updateActivationPolicy(to: .regular)
            }
    }
    
    var accessory: some View {
        VStack {
            ForEach(Array(trades.watchers.keys)) { id in
                Button(trades.watchers[id]?.symbol ?? "Unknown") {
                    updateActivationPolicy(to: .regular)
                    trades.selectedWatcher = id
                }
            }
            Divider()
            
            Button("New Window") {
                openWindow(id: "main")
                updateActivationPolicy(to: .regular)
            }
            .keyboardShortcut("o")
            
            Button(isRegularActivationPolicy ? "Hide" : "Show") {
                if isRegularActivationPolicy {
                    updateActivationPolicy(to: .prohibited)
                } else {
                    openWindow(id: "main")
                    updateActivationPolicy(to: .regular)
                }
            }
            .keyboardShortcut(isRegularActivationPolicy ? "h" : "s")
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
    
    func updateActivationPolicy(to policy: NSApplication.ActivationPolicy) {
        activationPolicy = policy
        appDelegate.updateActivationPolicy(to: policy)
    }
    
    class AppDelegate: NSObject, NSApplicationDelegate {
        @MainActor var activationPolicy: NSApplication.ActivationPolicy {
            NSApp.activationPolicy()
        }
        
        func applicationWillFinishLaunching(_ notification: Notification) {
            let raw = UserDefaults.standard.integer(forKey: "activationPolicy")
            guard NSApplication.ActivationPolicy(rawValue: raw) == .prohibited else {
                updateActivationPolicy(to: .regular)
                return
            }
            updateActivationPolicy(to: .prohibited)
        }
    
        @MainActor func updateActivationPolicy(to policy: NSApplication.ActivationPolicy) {
                NSApp.setActivationPolicy(policy)
                NSApp.activate(ignoringOtherApps: true)
        }
    }
}

#endif

import SwiftUI
import TradeInterface
import Runtime

@main
struct TradeApp: App {
    @State private var trades = TradeManager()
    
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            MenuBarContent()
                .environment(trades)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 18
                $0.size.width = 18 / ratio
                $0.isTemplate = true
                return $0
            }(NSImage(named: "MenuBarIcon")!)
            
            Image(nsImage: image)
                .renderingMode(.template)
                .foregroundColor(.primary)
        }
        
        Window(Bundle.main.displayName, id: "main") {
            ContentView()
                .environment(trades)
                .onAppear {
                    trades.initializeSockets()
                }
        }
        
        WindowGroup("Watcher", for: Watcher.ID.self) { $watcherId in
            if let watcherId = watcherId, let watcher = trades.watchers[watcherId] {
                WatcherView(watcher: watcher)
                    .navigationTitle("Watcher: \(watcher.displayName)")
            }
        }
        
        WindowGroup("Snapshot Preview", for: FileSnapshotsView.ViewModel.SnapshotPreview.self) { $snapshot in
            if let node = snapshot?.file {
                SnapshotView(node: node, fileProvider: trades.fileProvider)
            }
        }
        
        WindowGroup("Snapshot Playback", for: FileSnapshotsView.ViewModel.SnapshotPlayback.self) { $snapshot in
            if let node = snapshot?.file {
                SnapshotPlaybackView(node: node, fileProvider: trades.fileProvider)
            }
        }
        
        #else
        WindowGroup {
            ContentView()
                .environment(trades)
                .onAppear {
                    trades.initializeSockets()
                }
        }
        #endif
    }
}

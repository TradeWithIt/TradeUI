import SwiftUI
import TradeInterface

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

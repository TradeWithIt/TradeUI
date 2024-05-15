import SwiftUI

enum Stack {
    enum Orientation {
        case horizontal, vertical
    }

    enum Gravity {
        case start, center, end
        
        var vertical: VerticalAlignment {
            switch self {
            case .start:
                return .top
            case .center:
                return .center
            case .end:
                return .bottom
            }
        }

        var horizontal: HorizontalAlignment {
            switch self {
            case .start:
                return .leading
            case .center:
                return .center
            case .end:
                return .trailing
            }
        }
    }
    
    struct View<Content: SwiftUI.View>: SwiftUI.View {
        let orientation: Orientation
        var alignment: Gravity = .center
        var spacing: Double = 0
        @ViewBuilder let content: () -> Content
        
        var body: some SwiftUI.View {
            switch orientation {
            case .horizontal:
                HStack(alignment: alignment.vertical, spacing: spacing) { content() }
            case .vertical:
                VStack(alignment: alignment.horizontal, spacing: spacing) { content() }
            }
        }
    }
}

struct StackView_Previews: PreviewProvider {
    static var previews: some View {
        Stack.View(orientation: .vertical) {
            Text("🚀")
            Text("✅")
            Text("❤️")
        }
        
        Stack.View(orientation: .horizontal) {
            Text("🚀")
            Text("✅")
            Text("❤️")
        }
    }
}

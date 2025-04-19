import SwiftUI


private struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct RectPreferenceKey: PreferenceKey {
    typealias Value = CGRect
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension View {
    /**
        View modifier accepting state in order to reflect views size
        ~~~
         struct ContentView: View {
             @State var size: CGSize = .zero

             var body: some View {
                 HStack {
                     Rectangle()
                         .fill(Color.red)
                         .frame(width: 250, height: 50)
                         .overlay(Text("\(Int(size.width)):\(Int(size.height))"))
                 }.onSizeChange($size)
             }
         }
        ~~~
     - Parameter binding: Readonly binding for views size
     - Returns: view
    */
    func onSizeChange(_ binding: Binding<CGSize>) -> some View {
        self.onSizeChange { size in
            binding.wrappedValue = size
        }
    }

    /// Notifies about views size changes
    /// - Parameter closure: view size change callback
    /// - Returns: view
    func onSizeChange(_ closure: @escaping (CGSize) -> Void) -> some View {
        self.overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geo.size)
            }
        ).onPreferenceChange(SizePreferenceKey.self, perform: closure)
    }

    /**
        View modifier accepting state in order to reflect views frame in desired coordinate space.
        ~~~
         struct ContentView: View {
             @State var frame: CGRect = .zero

             var body: some View {
                 HStack {
                     Rectangle()
                         .fill(Color.red)
                         .frame(width: 250, height: 50)
                         .overlay(Text("\(Int(frame.size.width)):\(Int(frame.size.height))"))
                 }.onFrameChange($frame)
             }
         }
        ~~~
        You can specify coordinates by using modifier in this way:
        ~~~
        .onFrameChange($frame, in: .global)
        ~~~
        or
        ~~~
        .onFrameChange($frame, in: .local)
        ~~~
     - Parameter binding: Readonly binding for views rect
     - Returns: view
    */
    func onFrameChange(_ binding: Binding<CGRect>, in coordinateSpace: CoordinateSpace = .global) -> some View {
        return self.onFrameChange(in: coordinateSpace) { rect in
            binding.wrappedValue = rect
        }
    }

    /// Notifies about views rect changes
    /// - Parameters:
    ///   - coordinateSpace: Coordinate space in which rect should be return
    ///   - closure: view rect change callback
    /// - Returns: view
    func onFrameChange(in coordinateSpace: CoordinateSpace = .global, closure: @escaping (CGRect) -> Void) -> some View {
        self.overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(key: RectPreferenceKey.self, value: geo.frame(in: coordinateSpace))
            }
        ).onPreferenceChange(RectPreferenceKey.self, perform: closure)
    }
}

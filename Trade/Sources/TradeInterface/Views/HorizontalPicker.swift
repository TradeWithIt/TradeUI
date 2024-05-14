import Foundation
import SwiftUI

struct HPickerView<Content>: View where Content: Identifiable, Content: CustomStringConvertible {
    @Binding var selected: Content?
    let items: [Content]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scrollView in
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        ItemView(item: item, isSelected: item.id == selected?.id)
                            .onTapGesture {
                                withAnimation {
                                    selected = item
                                    scrollView.scrollTo(item.id, anchor: .center)
                                }
                            }
                    }
                }
            }
        }
    }

    struct ItemView<Item>: View where Item: CustomStringConvertible {
        var item: Item
        var isSelected: Bool

        var body: some View {
            Group {
                if isSelected {
                    Text(item.description)
                        .bold()
                        .overlay(Rectangle().frame(height: 2).padding(.top, 20), alignment: .bottom)
                } else {
                    Text(item.description)
                }
            }
        }
    }
}

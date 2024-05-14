import SwiftUI

struct SuggestionView: View {
    @Environment(\.dismissSearch) var dismissSearch
    
    let label: String
    let symbol: String
    let action: () -> Void
    
    var body: some View {
        Text(label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .searchCompletion(symbol)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
                dismissSearch()
            }
    }
}

import SwiftUI
import Brokerage
import Runtime

public struct FileSnapshotsView: View {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    
    @Environment(TradeManager.self) private var trades
    @State private var viewModel = ViewModel()
    @State private var selectedFile: FileNode?

    public var body: some View {
        fileBrowserView
            .task {
                Task {
                    viewModel.loadFileTree(url: trades.fileProvider.snapshotsDirectory)
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { viewModel.isPresentingSheet != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.isPresentingSheet = nil
                    }
                }
            )) {
                switch viewModel.isPresentingSheet {
                case .snapshotPreview:
                    SnapshotView(node: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
                case .snapshotPlayback:
                    SnapshotPlaybackView(node: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
                default:
                    EmptyView()
                }
            }
    }

    private var fileBrowserView: some View {
        List(viewModel.fileTree, children: \.children) { file in
            fileItemView(for: file)
                .listRowSeparator(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func fileItemView(for file: FileNode) -> some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(file.isDirectory ? .yellow : .gray)
            Text(file.name)
            Spacer()
        }
        .contextMenu {
            if !file.isDirectory {
                Button(action: {
                    handleOpenFile(type: .snapshotPreview(node: file))
                }) {
                    Label("Preview", systemImage: "eye.fill")
                }
                Button(action: {
                    handleOpenFile(type: .snapshotPlayback(node: file))
                }) {
                    Label("Play", systemImage: "play.fill")
                }
            }
        }
    }
    
    private func handleOpenFile(type: ViewModel.PresentedSheetType) {
        #if os(macOS)
        switch type {
        case .snapshotPreview(let node):
            openWindow(value: ViewModel.SnapshotPreview(file: node))
        case .snapshotPlayback(let node):
            openWindow(value: ViewModel.SnapshotPlayback(file: node))
        }
        #else
        viewModel.isPresentingSheet = type
        #endif
    }
}

#Preview {
    FileSnapshotsView()
}

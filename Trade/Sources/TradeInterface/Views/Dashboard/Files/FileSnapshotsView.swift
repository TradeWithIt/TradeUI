import SwiftUI
import Brokerage
import Runtime

public struct FileSnapshotsView: View {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    
    @Environment(TradeManager.self) private var trades
    @State private var viewModel = ViewModel()
    
    public var body: some View {
        snapshotsView
            .task {
                Task {
                    viewModel.loadSnapshotFileNames(url: trades.fileProvider.snapshotsDirectory)
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
                    SnapshotView(fileName: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
                case .snapshotPlayback:
                    SnapshotPlaybackView(fileName: viewModel.selectedSnapshot, fileProvider: trades.fileProvider)
                default:
                    EmptyView()
                }
            }
    }
    
    private var snapshotsView: some View {
        VStack(alignment: .leading) {
            Divider()
            Button("Load data") {
                do {
                    try viewModel.saveHistoryToFile(
                        contract: Instrument.BTC,
                        interval: 300,
                        market: trades.market,
                        fileProvider: trades.fileProvider
                    )
                } catch {
                    print("Failed saving hisotry to file", error)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            
            ForEach(viewModel.snapshotFileNames, id: \.self) { fileName in
                VStack {
                    Text(fileName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack {
                        Button(action: {
                            handleOpenView(type: .snapshotPreview(fileName: fileName))
                        }) {
                            Image(systemName: "eye.fill")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            handleOpenView(type: .snapshotPlayback(fileName: fileName))
                        }) {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(maxWidth: .infinity)
                    }.padding(.top, 4)
                }
            }
        }
    }
    
    private func handleOpenView(type: ViewModel.PresentedSheetType) {
        #if os(macOS)
        switch type {
        case .snapshotPreview(let fileName):
            openWindow(value: ViewModel.SnapshotPreview(fileName: fileName))
        case .snapshotPlayback(let fileName):
            openWindow(value: ViewModel.SnapshotPlayback(fileName: fileName))
        }
        #else
        viewModel.isPresentingSheet = type
        #endif
    }
}

#Preview {
    FileSnapshotsView()
}

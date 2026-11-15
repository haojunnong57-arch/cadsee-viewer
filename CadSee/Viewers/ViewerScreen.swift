import SwiftUI

struct ViewerScreen: View {
    let record: FileRecord
    @EnvironmentObject private var store: LibraryStore
    @State private var showInfo = false

    var body: some View {
        viewer
            .navigationTitle(record.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: record.url)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfo) {
                FileDetailView(record: record)
            }
            .onAppear {
                store.touchOpened(record)
            }
    }

    @ViewBuilder
    private var viewer: some View {
        switch record.kind.viewerKind {
        case .some(.scenekit):
            SceneKitViewer(url: record.url)
        case .some(.web3D):
            WebViewer(url: record.url, mode: .threeD)
        case .some(.webDXF):
            WebViewer(url: record.url, mode: .dxf)
        case .some(.pdf):
            PDFViewer(url: record.url)
        case .some(.image):
            ImageViewer(url: record.url)
        case .some(.rawWeb):
            RawWebViewer(url: record.url)
        case .none:
            UnsupportedFileView()
        }
    }
}

struct UnsupportedFileView: View {
    var body: some View {
        ContentUnavailableView(
            "不支持的文件格式",
            systemImage: "questionmark.folder",
            description: Text("支持：STL、OBJ、PLY、STEP、IGES、DXF、PDF、SVG 及常见图片")
        )
    }
}

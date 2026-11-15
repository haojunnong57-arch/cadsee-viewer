import SwiftUI
import WebKit

/// 直接用 WKWebView 打开的文件（SVG 等）
struct RawWebViewer: View {
    let url: URL

    var body: some View {
        RawWebContainer(url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

struct RawWebContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.backgroundColor = .systemBackground
        view.isOpaque = true
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

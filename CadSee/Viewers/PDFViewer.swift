import SwiftUI
import PDFKit

struct PDFViewer: View {
    let url: URL

    var body: some View {
        PDFKitContainer(url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

struct PDFKitContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        view.pageShadowsEnabled = true
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

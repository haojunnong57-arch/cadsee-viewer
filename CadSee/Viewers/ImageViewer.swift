import SwiftUI
import UIKit

struct ImageViewer: View {
    let url: URL

    var body: some View {
        ZoomableImageContainer(url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

/// 布局时回调的滚动视图，保证图片初始适配屏幕
final class ViewerScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

struct ZoomableImageContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> ViewerScrollView {
        let scroll = ViewerScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.backgroundColor = .black
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false

        let imageView = UIImageView(image: UIImage(contentsOfFile: url.path))
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        scroll.onLayout = { [weak scroll] in
            guard let scroll else { return }
            context.coordinator.layout(scroll)
        }

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: ViewerScrollView, context: Context) {
        context.coordinator.layout(scroll)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            layout(scrollView)
        }

        func layout(_ scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 1, bounds.height > 1 else { return }
            let fit = Self.aspectFit(size: image.size, in: bounds)
            if scrollView.zoomScale <= 1.001, imageView.frame.size != fit {
                imageView.frame = CGRect(origin: .zero, size: fit)
                scrollView.contentSize = fit
            }
            centerContent(scrollView)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            if scroll.zoomScale > 1.1 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let rect = CGRect(x: point.x - 60, y: point.y - 60, width: 120, height: 120)
                scroll.zoom(to: rect, animated: true)
            }
        }

        private func centerContent(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width / 2 + offsetX,
                y: scrollView.contentSize.height / 2 + offsetY
            )
        }

        private static func aspectFit(size: CGSize, in bounds: CGSize) -> CGSize {
            guard size.width > 0, size.height > 0 else { return bounds }
            let scale = min(bounds.width / size.width, bounds.height / size.height)
            return CGSize(width: size.width * scale, height: size.height * scale)
        }
    }
}

import Foundation
import Combine

/// 把打包在 App 内的 Web 查看器资源（three.js / occt-import-js 等）
/// 一次性复制到缓存目录，并把要查看的模型放入其中，供 WKWebView 离线加载。
@MainActor
final class WebRootManager: ObservableObject {
    @Published private(set) var pageURL: URL?
    @Published private(set) var modelExt: String = ""
    @Published private(set) var errorMessage: String?
    let rootURL: URL

    init() {
        rootURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebRoot", isDirectory: true)
    }

    func prepare(modelURL: URL) async {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            let marker = rootURL.appendingPathComponent("asset-version.txt")
            let installed = (try? String(contentsOf: marker, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if installed != version {
                try? fm.removeItem(at: rootURL)
                try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
                let bundleAssets = Bundle.main.url(forResource: "WebAssets", withExtension: nil)
                    ?? Bundle.main.resourceURL?.appendingPathComponent("WebAssets")
                if let bundleAssets,
                   let items = try? fm.contentsOfDirectory(
                       at: bundleAssets,
                       includingPropertiesForKeys: nil
                   ) {
                    for item in items {
                        try fm.copyItem(
                            at: item,
                            to: rootURL.appendingPathComponent(item.lastPathComponent)
                        )
                    }
                }
                try version.write(to: marker, atomically: true, encoding: .utf8)
            }

            let ext = modelURL.pathExtension.lowercased()
            guard !ext.isEmpty else {
                errorMessage = "不支持的文件"
                return
            }
            modelExt = ext
            let target = rootURL.appendingPathComponent("model.\(ext)")
            try? fm.removeItem(at: target)
            try fm.copyItem(at: modelURL, to: target)
            pageURL = rootURL.appendingPathComponent("index.html")
        } catch {
            errorMessage = "文件准备失败：\(error.localizedDescription)"
        }
    }
}

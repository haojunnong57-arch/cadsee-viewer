import Foundation
import WebKit

/// 自定义 URL Scheme 处理器：让 WKWebView 以 cadsee:// 协议
/// 完全离线地读取缓存目录中的 HTML/JS/WASM 与模型文件，
/// 避免 file:// 的跨域与读取限制。
final class WebSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "cadsee"
    let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme?.lowercased() == Self.scheme else {
            urlSchemeTask.didFailWithError(Self.makeError(code: -1, message: "无效请求"))
            return
        }
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty { path = "index.html" }
        let fileURL = root.appendingPathComponent(path).standardizedFileURL
        guard fileURL.path.hasPrefix(root.path) else {
            urlSchemeTask.didFailWithError(Self.makeError(code: -2, message: "拒绝访问"))
            return
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(Self.makeError(code: -3, message: "文件不存在"))
            return
        }
        let mime = Self.mimeType(for: fileURL.pathExtension)
        let charset = (mime.hasPrefix("text") || mime == "application/json") ? "; charset=utf-8" : ""
        // 关键：必须返回 HTTPURLResponse（statusCode=200），JS 的 fetch() 才能拿到
        // 正确的 resp.status / resp.ok；否则会得到 status=0，报“读取文件失败 (0)”。
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime + charset,
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*"
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func makeError(code: Int, message: String) -> NSError {
        NSError(
            domain: "com.cadsee.web",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "wasm": return "application/wasm"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }
}

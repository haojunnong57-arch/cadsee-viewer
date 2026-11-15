import SwiftUI
import WebKit

/// 发送给 Web 查看器的操作命令
enum WebCommand {
    case setDisplay(WebViewer.DisplayMode)
    case setTheme(Bool)
    case viewAngle(WebViewer.ViewAngle)
    case resetView
}

struct WebViewer: View {
    enum Mode {
        case threeD
        case dxf
    }

    let url: URL
    let mode: Mode

    enum DisplayMode: String, CaseIterable, Identifiable {
        case solid = "实体"
        case wire = "线框"
        var id: String { rawValue }
        var jsValue: String { self == .solid ? "solid" : "wire" }
    }

    enum ViewAngle: String, CaseIterable, Identifiable {
        case iso = "等轴测"
        case front = "正面"
        case top = "俯视"
        var id: String { rawValue }
        var jsValue: String {
            switch self {
            case .iso: return "iso"
            case .front: return "front"
            case .top: return "top"
            }
        }
    }

    @AppStorage("viewerThemeDark") private var themeDark = true
    @State private var displayMode: DisplayMode = .solid
    @State private var stats = ""
    @State private var phase: Phase = .preparing
    @State private var command: WebCommand = .resetView
    @State private var commandID = UUID()
    @StateObject private var webRoot = WebRootManager()

    private enum Phase {
        case preparing
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
        ZStack {
            Color(themeDark ? Color(white: 0.08) : Color(white: 0.95))
                .ignoresSafeArea()

            // 容器保持稳定身份，避免 phase 切换时重建 WKWebView 导致二次加载
            if let page = webRoot.pageURL {
                webContainer(pageURL: page)
            }

            switch phase {
            case .preparing:
                loadingView("正在准备…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeDark ? Color(white: 0.08) : Color(white: 0.95))
            case .loading:
                EmptyView()
            case .ready:
                EmptyView()
            case .failed(let message):
                ContentUnavailableView(
                    "无法打开",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeDark ? Color(white: 0.08) : Color(white: 0.95))
            }

            VStack {
                Spacer()
                controlBar
            }
        }
        .task {
            await prepare()
        }
    }

    private func prepare() async {
        await webRoot.prepare(modelURL: url)
        if let message = webRoot.errorMessage {
            phase = .failed(message)
        } else {
            phase = .loading
        }
    }

    private func webContainer(pageURL: URL) -> some View {
        WebContainer(
            pageURL: pageURL,
            webRootURL: webRoot.rootURL,
            mode: mode,
            ext: webRoot.modelExt,
            command: command,
            commandID: commandID,
            onEvent: handleEvent
        )
    }

    private func handleEvent(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }
        switch type {
        case "status":
            let value = payload["value"] as? String ?? ""
            switch value {
            case "ready":
                phase = .ready
            case "failed":
                phase = .failed(payload["message"] as? String ?? "解析失败")
            default:
                break
            }
        case "stats":
            if let triangles = payload["triangles"] as? Int, triangles > 0 {
                stats = "三角面 \(triangles.formatted())"
            }
        default:
            break
        }
    }

    private func loadingView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            if !stats.isEmpty {
                Text(stats)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            HStack(spacing: 12) {
                Picker("显示模式", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .onChange(of: displayMode) { _, newValue in
                    send(.setDisplay(newValue))
                }

                Menu {
                    ForEach(ViewAngle.allCases) { angle in
                        Button(angle.rawValue) { send(.viewAngle(angle)) }
                    }
                    Divider()
                    Button("重置视图") { send(.resetView) }
                } label: {
                    Image(systemName: "view.3d")
                }

                Button {
                    themeDark.toggle()
                    send(.setTheme(themeDark))
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.bottom, 10)
    }

    private func send(_ command: WebCommand) {
        self.command = command
        commandID = UUID()
    }
}

struct WebContainer: UIViewRepresentable {
    let pageURL: URL
    let webRootURL: URL
    let mode: WebViewer.Mode
    let ext: String
    let command: WebCommand
    let commandID: UUID
    let onEvent: ([String: Any]) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "cadsee")

        let meta: [String: Any] = ["ext": ext, "mode": mode == .dxf ? "dxf" : "3d"]
        if let data = try? JSONSerialization.data(withJSONObject: meta),
           let json = String(data: data, encoding: .utf8) {
            let script = WKUserScript(
                source: "window.CADSEE_META = \(json);",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            controller.addUserScript(script)
        }

        config.userContentController = controller
        config.setURLSchemeHandler(
            WebSchemeHandler(root: webRootURL),
            forURLScheme: WebSchemeHandler.scheme
        )
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        if #available(iOS 16.4, *) {
            view.isInspectable = true
        }
        if let requestURL = URL(string: "\(WebSchemeHandler.scheme)://app/index.html") {
            view.load(URLRequest(url: requestURL))
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.lastCommandID != commandID else { return }
        context.coordinator.lastCommandID = commandID
        let js: String
        switch command {
        case .setDisplay(let display):
            js = "window.CADSEE && CADSEE.setDisplayMode('\(display.jsValue)');"
        case .setTheme(let dark):
            js = "window.CADSEE && CADSEE.setTheme(\(dark));"
        case .viewAngle(let angle):
            js = "window.CADSEE && CADSEE.setViewAngle('\(angle.jsValue)');"
        case .resetView:
            js = "window.CADSEE && CADSEE.resetView();"
        }
        view.evaluateJavaScript(js, completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onEvent: ([String: Any]) -> Void
        var lastCommandID: UUID?

        init(onEvent: @escaping ([String: Any]) -> Void) {
            self.onEvent = onEvent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "cadsee", let body = message.body as? [String: Any] else { return }
            DispatchQueue.main.async {
                self.onEvent(body)
            }
        }
    }
}

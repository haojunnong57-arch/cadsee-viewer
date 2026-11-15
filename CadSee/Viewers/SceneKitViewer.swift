import SwiftUI
import SceneKit
import ModelIO

/// 发送给 SceneKit 容器的操作命令
enum SceneKitCommand {
    case viewAngle(SceneKitViewer.ViewAngle)
    case projection(Bool)
    case resetView
}

struct SceneKitViewer: View {
    let url: URL

    enum DisplayMode: String, CaseIterable, Identifiable {
        case solid = "实体"
        case wire = "线框"
        var id: String { rawValue }
    }

    enum ViewAngle: String, CaseIterable, Identifiable {
        case iso = "等轴测"
        case front = "正面"
        case top = "俯视"
        var id: String { rawValue }
    }

    @AppStorage("viewerThemeDark") private var themeDark = true
    @State private var displayMode: DisplayMode = .solid
    @State private var isOrtho = false
    @State private var stats = ""
    @State private var command: SceneKitCommand = .resetView
    @State private var commandID = UUID()
    @StateObject private var loader = SceneLoader()

    var body: some View {
        ZStack {
            SceneKitContainer(
                loader: loader,
                displayMode: displayMode,
                themeDark: themeDark,
                isOrtho: isOrtho,
                command: command,
                commandID: commandID,
                onStats: { stats = $0 }
            )
            switch loader.state {
            case .loading:
                ProgressView("正在加载模型…")
                    .controlSize(.large)
                    .tint(.primary)
            case .failed:
                ContentUnavailableView(
                    "无法打开",
                    systemImage: "exclamationmark.triangle",
                    description: Text("该文件无法解析为三维模型")
                )
            default:
                EmptyView()
            }
            VStack {
                Spacer()
                controlBar
            }
        }
        .background(themeDark ? Color(white: 0.09) : Color(white: 0.94))
        .task {
            await loader.load(url: url)
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
                    isOrtho.toggle()
                    send(.projection(isOrtho))
                } label: {
                    Image(systemName: isOrtho ? "square" : "square.dashed")
                }

                Button {
                    themeDark.toggle()
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.bottom, 10)
    }

    private func send(_ command: SceneKitCommand) {
        self.command = command
        commandID = UUID()
    }
}

/// 负责后台解析模型（ModelIO），主线程组装 SCNScene
@MainActor
final class SceneLoader: ObservableObject {
    enum LoadState {
        case idle, loading, loaded, failed
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var scene: SCNScene?

    private enum LoadError: Error {
        case unsupported
    }

    func load(url: URL) async {
        guard state == .idle else { return }
        state = .loading
        let ext = url.pathExtension.lowercased()
        let isNative = ext == "dae" || ext == "scn"
        do {
            let loaded: SCNScene = try await Task.detached(priority: .userInitiated) {
                if isNative {
                    guard let scene = try? SCNScene(url: url, options: nil) else {
                        throw LoadError.unsupported
                    }
                    return scene
                }
                let asset = MDLAsset(url: url)
                asset.loadTextures()
                guard asset.count > 0 else { throw LoadError.unsupported }
                return SCNScene(mdlAsset: asset)
            }.value
            scene = loaded
            state = .loaded
        } catch {
            state = .failed
        }
    }
}

struct SceneKitContainer: UIViewRepresentable {
    @ObservedObject var loader: SceneLoader
    let displayMode: SceneKitViewer.DisplayMode
    let themeDark: Bool
    let isOrtho: Bool
    let command: SceneKitCommand
    let commandID: UUID
    let onStats: (String) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = Self.background(themeDark)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.cameraControlConfiguration.allowsTranslation = false
        let scene = SCNScene()
        view.scene = scene
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if view.scene !== loader.scene, let scene = loader.scene {
            view.scene = scene
            Self.addLights(to: scene)
            context.coordinator.materialStates = Self.collectMaterials(in: scene)
            Self.configureMaterials(scene)
            context.coordinator.appliedDisplayMode = .solid
            context.coordinator.appliedThemeDark = themeDark
            context.coordinator.appliedOrtho = false
            Self.frameScene(view, context: context)
            Self.applyProjection(false, view: view, context: context)
            let stats = Self.statsText(scene)
            DispatchQueue.main.async {
                onStats(stats)
            }
        }

        if context.coordinator.appliedDisplayMode != displayMode {
            context.coordinator.appliedDisplayMode = displayMode
            Self.applyDisplayMode(displayMode, context: context)
        }

        if context.coordinator.appliedThemeDark != themeDark {
            context.coordinator.appliedThemeDark = themeDark
            view.backgroundColor = Self.background(themeDark)
            view.scene?.background.contents = Self.background(themeDark)
        }

        if context.coordinator.appliedOrtho != isOrtho {
            context.coordinator.appliedOrtho = isOrtho
            Self.applyProjection(isOrtho, view: view, context: context)
        }

        if context.coordinator.lastCommandID != commandID {
            context.coordinator.lastCommandID = commandID
            Self.handle(command, view: view, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var materialStates: [(material: SCNMaterial, original: SCNFillMode)] = []
        var appliedDisplayMode: SceneKitViewer.DisplayMode = .solid
        var appliedThemeDark = true
        var appliedOrtho = false
        var lastCommandID: UUID?
        weak var cameraNode: SCNNode?
        weak var targetNode: SCNNode?
        var viewRadius: Float = 1
    }

    // MARK: - 场景构建

    private static func background(_ dark: Bool) -> UIColor {
        dark
            ? UIColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)
            : UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    }

    private static func addLights(to scene: SCNScene) {
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 420
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 950
        directionalLight.castsShadow = false
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 4, 0)

        scene.rootNode.addChildNode(ambientNode)
        scene.rootNode.addChildNode(directionalNode)
    }

    private static func collectMaterials(in scene: SCNScene) -> [(SCNMaterial, SCNFillMode)] {
        var states: [(SCNMaterial, SCNFillMode)] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ node: SCNNode) {
            if let geometry = node.geometry {
                for material in geometry.materials where !seen.contains(ObjectIdentifier(material)) {
                    seen.insert(ObjectIdentifier(material))
                    states.append((material, material.fillMode))
                }
            }
            for child in node.childNodes {
                visit(child)
            }
        }
        visit(scene.rootNode)
        return states
    }

    private static func configureMaterials(_ scene: SCNScene) {
        scene.rootNode.enumerateHierarchy { node, _ in
            if let geometry = node.geometry {
                for material in geometry.materials {
                    material.isDoubleSided = true
                    material.lightingModel = .blinn
                }
            }
        }
    }

    private static func statsText(_ scene: SCNScene) -> String {
        var total = 0
        scene.rootNode.enumerateHierarchy { node, _ in
            if let geometry = node.geometry {
                for index in 0..<geometry.elementCount {
                    total += geometry.element(at: index).primitiveCount
                }
            }
        }
        return total > 0 ? "三角面 \(total.formatted())" : ""
    }

    // MARK: - 取景

    private static func frameScene(_ view: SCNView, context: Context) {
        guard let scene = view.scene else { return }
        let root = scene.rootNode
        let (boxMin, boxMax) = root.boundingBox
        let isEmpty = abs(boxMin.x - boxMax.x) < 0.0001
            && abs(boxMin.y - boxMax.y) < 0.0001
            && abs(boxMin.z - boxMax.z) < 0.0001
        let minV = isEmpty ? SCNVector3(-1, -1, -1) : boxMin
        let maxV = isEmpty ? SCNVector3(1, 1, 1) : boxMax

        let center = SCNVector3(
            (minV.x + maxV.x) / 2,
            (minV.y + maxV.y) / 2,
            (minV.z + maxV.z) / 2
        )
        let size = SCNVector3(maxV.x - minV.x, maxV.y - minV.y, maxV.z - minV.z)
        let radius = max(max(size.x, size.y), size.z) / 2
        context.coordinator.viewRadius = max(radius, 0.001)

        let target: SCNNode
        if let existing = context.coordinator.targetNode {
            target = existing
        } else {
            target = SCNNode()
            scene.rootNode.addChildNode(target)
            context.coordinator.targetNode = target
        }
        target.position = center

        let cameraNode: SCNNode
        if let existing = context.coordinator.cameraNode {
            cameraNode = existing
        } else {
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 55
            cameraNode.camera?.automaticallyAdjustsZRange = true
            scene.rootNode.addChildNode(cameraNode)
            context.coordinator.cameraNode = cameraNode
        }
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.orthographicScale = Double(max(radius, 0.001) * 1.7)
        cameraNode.constraints = [SCNLookAtConstraint(target: target)]
        view.pointOfView = cameraNode

        placeCamera(direction: SCNVector3(0.55, -0.62, 0.9), view: view, context: context)
    }

    private static func placeCamera(direction rawDir: SCNVector3, view: SCNView, context: Context) {
        guard let cameraNode = context.coordinator.cameraNode,
              let target = context.coordinator.targetNode else { return }
        let radius = context.coordinator.viewRadius
        let center = target.position
        let length = sqrt(rawDir.x * rawDir.x + rawDir.y * rawDir.y + rawDir.z * rawDir.z)
        let dir = SCNVector3(rawDir.x / length, rawDir.y / length, rawDir.z / length)
        let distance: Float
        if cameraNode.camera?.usesOrthographicProjection == true {
            distance = radius * 4
        } else {
            let fov: Float = 55 * .pi / 180
            distance = radius / tan(fov / 2) * 1.6
        }
        cameraNode.position = SCNVector3(
            center.x + dir.x * distance,
            center.y + dir.y * distance,
            center.z + dir.z * distance
        )
    }

    private static func handle(_ command: SceneKitCommand, view: SCNView, context: Context) {
        switch command {
        case .viewAngle(let angle):
            let direction: SCNVector3
            switch angle {
            case .iso:
                direction = SCNVector3(0.55, -0.62, 0.9)
            case .front:
                direction = SCNVector3(0, 0, 1)
            case .top:
                direction = SCNVector3(0.01, 1, 0.01)
            }
            placeCamera(direction: direction, view: view, context: context)
        case .projection(let ortho):
            applyProjection(ortho, view: view, context: context)
        case .resetView:
            frameScene(view, context: context)
        }
    }

    private static func applyProjection(_ ortho: Bool, view: SCNView, context: Context) {
        guard let cameraNode = context.coordinator.cameraNode else { return }
        cameraNode.camera?.usesOrthographicProjection = ortho
        if ortho {
            cameraNode.camera?.orthographicScale = Double(context.coordinator.viewRadius * 1.7)
        } else {
            placeCamera(direction: SCNVector3(0.55, -0.62, 0.9), view: view, context: context)
        }
    }

    private static func applyDisplayMode(_ mode: SceneKitViewer.DisplayMode, context: Context) {
        for state in context.coordinator.materialStates {
            state.material.fillMode = mode == .wire ? .lines : state.original
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("viewerThemeDark") private var viewerThemeDark = true

    var body: some View {
        Form {
            Section("外观") {
                Picker("界面外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                Picker("3D 查看背景", selection: $viewerThemeDark) {
                    Text("深色").tag(true)
                    Text("浅色").tag(false)
                }
            }
            Section("格式支持") {
                NavigationLink {
                    FormatSupportView()
                } label: {
                    Label("支持的文件格式", systemImage: "list.bullet.rectangle")
                }
            }
            Section("关于") {
                LabeledContent("版本", value: appVersion)
                NavigationLink {
                    LicensesView()
                } label: {
                    Label("开源许可", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct FormatSupportView: View {
    private let groups: [(String, String, [String])] = [
        ("三维模型", "Web 渲染引擎（three.js）", ["STL", "OBJ", "PLY"]),
        ("原生场景", "SceneKit 原生渲染", ["USDZ", "DAE", "SCN"]),
        ("CAD 模型", "OpenCASCADE WASM 引擎解析", ["STEP", "STP", "IGES", "IGS", "BREP", "glTF", "GLB", "3MF"]),
        ("平面图纸", "DXF / PDF / SVG", ["DXF", "PDF", "SVG"]),
        ("图片", "系统相册格式", ["PNG", "JPG", "HEIC", "WEBP", "GIF", "TIFF", "BMP"])
    ]

    var body: some View {
        List {
            ForEach(groups, id: \.0) { group in
                Section {
                    Text(group.1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(group.2.joined(separator: " · "))
                        .font(.footnote)
                } header: {
                    Text(group.0)
                }
            }
        }
        .navigationTitle("支持格式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

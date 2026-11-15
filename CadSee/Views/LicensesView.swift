import SwiftUI

struct LicensesView: View {
    private struct Project {
        let name: String
        let url: String
        let license: String
        let purpose: String
    }

    private let projects: [Project] = [
        Project(
            name: "three.js",
            url: "https://github.com/mrdoob/three.js",
            license: "MIT License",
            purpose: "WebGL 三维渲染引擎（STL / OBJ / PLY / glTF / 3MF 解析）"
        ),
        Project(
            name: "occt-import-js",
            url: "https://github.com/kovacsv/occt-import-js",
            license: "LGPL-2.1",
            purpose: "基于 OpenCASCADE (OCCT) 的 WebAssembly CAD 解析引擎（STEP / IGES / BREP）"
        ),
        Project(
            name: "three-dxf",
            url: "https://github.com/gdsestimating/three-dxf",
            license: "MIT License",
            purpose: "DXF 二维图纸渲染"
        ),
        Project(
            name: "dxf-parser",
            url: "https://github.com/gdsestimating/dxf-parser",
            license: "MIT License",
            purpose: "DXF 文件解析（three-dxf 的依赖）"
        ),
        Project(
            name: "fflate",
            url: "https://github.com/101arrowz/fflate",
            license: "MIT License",
            purpose: "3MF 文件解压"
        ),
        Project(
            name: "Open CASCADE Technology",
            url: "https://dev.opencascade.org",
            license: "LGPL 2.1 (with exception)",
            purpose: "occt-import-js 所基于的 CAD 几何内核"
        )
    ]

    var body: some View {
        List {
            Section {
                Text("本应用使用了以下开源项目，感谢所有贡献者。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("开源组件") {
                ForEach(projects, id: \.name) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(project.purpose)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(project.license)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                            Link("项目主页", destination: URL(string: project.url)!)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("开源许可")
        .navigationBarTitleDisplayMode(.inline)
    }
}

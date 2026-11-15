import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ViewerKind {
    case scenekit
    case web3D
    case webDXF
    case pdf
    case image
    case rawWeb
}

enum FileKind: Hashable {
    case nativeScene
    case mesh3D
    case cad
    case dxf
    case pdf
    case svg
    case image
    case unsupported

    init(ext: String) {
        switch ext.lowercased() {
        case "dae", "scn", "usdz":
            self = .nativeScene
        case "stl", "obj", "ply":
            self = .mesh3D
        case "step", "stp", "iges", "igs", "brep", "gltf", "glb", "3mf":
            self = .cad
        case "dxf":
            self = .dxf
        case "pdf":
            self = .pdf
        case "svg":
            self = .svg
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "tif", "tiff", "bmp":
            self = .image
        default:
            self = .unsupported
        }
    }

    /// 导入文件时允许的扩展名（全部）
    static let supportedExtensions: [String] = [
        "stl", "obj", "ply", "usdz", "dae", "scn",
        "step", "stp", "iges", "igs", "brep", "gltf", "glb", "3mf",
        "dxf", "pdf", "svg",
        "png", "jpg", "jpeg", "heic", "webp", "gif", "tif", "tiff", "bmp"
    ]

    /// 文件导入器允许的内容类型
    static var importTypes: [UTType] {
        var result = Set(supportedExtensions.compactMap { UTType(filenameExtension: $0) })
        result.insert(.data)
        return Array(result)
    }

    var displayName: String {
        switch self {
        case .nativeScene: return "三维模型"
        case .mesh3D: return "三维模型"
        case .cad: return "CAD 模型"
        case .dxf: return "DXF 图纸"
        case .pdf: return "PDF 文档"
        case .svg: return "SVG 图形"
        case .image: return "图片"
        case .unsupported: return "其他文件"
        }
    }

    var symbol: String {
        switch self {
        case .nativeScene: return "cube.transparent"
        case .mesh3D: return "cube.transparent"
        case .cad: return "rotate.3d"
        case .dxf: return "pencil.and.ruler"
        case .pdf: return "doc.richtext"
        case .svg: return "doc"
        case .image: return "photo"
        case .unsupported: return "questionmark.folder"
        }
    }

    var tint: Color {
        switch self {
        case .nativeScene: return .blue
        case .mesh3D: return .blue
        case .cad: return .indigo
        case .dxf: return .orange
        case .pdf: return .red
        case .svg: return .purple
        case .image: return .teal
        case .unsupported: return .gray
        }
    }

    var viewerKind: ViewerKind? {
        switch self {
        case .nativeScene: return .scenekit
        case .mesh3D: return .web3D
        case .cad: return .web3D
        case .dxf: return .webDXF
        case .pdf: return .pdf
        case .svg: return .rawWeb
        case .image: return .image
        case .unsupported: return nil
        }
    }
}

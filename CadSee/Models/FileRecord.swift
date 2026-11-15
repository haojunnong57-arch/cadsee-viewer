import Foundation

struct FileRecord: Identifiable, Hashable {
    /// 库目录中的文件名（作为稳定 id）
    let id: String
    let name: String
    let ext: String
    let size: Int64
    let dateAdded: Date
    var lastOpened: Date?

    var kind: FileKind { FileKind(ext: ext) }

    var url: URL { LibraryStore.libraryDirectory.appendingPathComponent(id) }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var dateText: String {
        dateAdded.formatted(date: .abbreviated, time: .omitted)
    }
}

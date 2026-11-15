import Foundation
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var files: [FileRecord] = []
    @Published var pendingAlert: String?

    nonisolated static var libraryDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Library", isDirectory: true)
    }

    private var lastOpened: [String: Date] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: "lastOpenedTimes") as? [String: TimeInterval] ?? [:]
            return raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
        set {
            let raw = newValue.mapValues { $0.timeIntervalSince1970 }
            UserDefaults.standard.set(raw, forKey: "lastOpenedTimes")
        }
    }

    init() {
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.libraryDirectory, withIntermediateDirectories: true)
        let urls = (try? fm.contentsOfDirectory(
            at: Self.libraryDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey]
        )) ?? []

        var opened = lastOpened
        var liveIDs = Set<String>()
        let records: [FileRecord] = urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey])
            if values?.isDirectory == true { return nil }
            let id = url.lastPathComponent
            liveIDs.insert(id)
            let ext = url.pathExtension.lowercased()
            return FileRecord(
                id: id,
                name: url.deletingPathExtension().lastPathComponent,
                ext: ext,
                size: Int64(values?.fileSize ?? 0),
                dateAdded: values?.creationDate ?? .distantPast,
                lastOpened: opened[id]
            )
        }

        opened = opened.filter { liveIDs.contains($0.key) }
        lastOpened = opened
        files = records.sorted { $0.dateAdded > $1.dateAdded }
    }

    /// 从系统文件选择器 / “用其他应用打开”导入文件
    func importFiles(from urls: [URL]) async {
        let failures: [String] = await Task.detached(priority: .userInitiated) {
            var failed: [String] = []
            for url in urls {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                let ext = url.pathExtension.lowercased()
                guard !ext.isEmpty, FileKind.supportedExtensions.contains(ext) else { continue }
                let dest = Self.uniqueURL(for: url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                } catch {
                    failed.append(url.lastPathComponent)
                }
            }
            return failed
        }.value
        refresh()
        if !failures.isEmpty {
            pendingAlert = "以下文件导入失败：\n" + failures.joined(separator: "\n")
        }
    }

    func delete(_ record: FileRecord) {
        try? FileManager.default.removeItem(at: record.url)
        var opened = lastOpened
        opened.removeValue(forKey: record.id)
        lastOpened = opened
        refresh()
    }

    func rename(_ record: FileRecord, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != record.name else { return }
        let fileName = record.ext.isEmpty ? trimmed : "\(trimmed).\(record.ext)"
        let dest = Self.uniqueURL(for: fileName)
        do {
            try FileManager.default.moveItem(at: record.url, to: dest)
            var opened = lastOpened
            let value = opened.removeValue(forKey: record.id)
            opened[dest.lastPathComponent] = value
            lastOpened = opened
            refresh()
        } catch {
            pendingAlert = "重命名失败：\(error.localizedDescription)"
        }
    }

    func touchOpened(_ record: FileRecord) {
        var opened = lastOpened
        opened[record.id] = Date()
        lastOpened = opened
        if let index = files.firstIndex(where: { $0.id == record.id }) {
            files[index].lastOpened = Date()
        }
    }

    nonisolated private static func uniqueURL(for name: String) -> URL {
        let base = libraryDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: base.path) else { return base }
        let ext = base.pathExtension
        let stem = base.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let candidate = libraryDirectory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}

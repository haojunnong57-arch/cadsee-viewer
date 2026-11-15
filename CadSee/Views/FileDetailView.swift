import SwiftUI

struct FileDetailView: View {
    let record: FileRecord
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        NavigationStack {
            List {
                Section("文件信息") {
                    LabeledContent("名称", value: record.name)
                    LabeledContent("格式", value: record.ext.uppercased())
                    LabeledContent("类型", value: record.kind.displayName)
                    LabeledContent("大小", value: record.sizeText)
                    LabeledContent("添加时间", value: record.dateAdded.formatted(date: .long, time: .shortened))
                }
                Section("操作") {
                    ShareLink(item: record.url) {
                        Label("共享文件", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        store.delete(record)
                        dismiss()
                    } label: {
                        Label("删除文件", systemImage: "trash")
                    }
                }
                Section("支持的格式") {
                    Text(FileKind.supportedExtensions.map { $0.uppercased() }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("文件信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("完成") { dismiss() }
            }
        }
    }
}

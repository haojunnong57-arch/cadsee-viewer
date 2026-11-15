import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var renameTarget: FileRecord?
    @State private var showRename = false
    @State private var renameText = ""

    private var filtered: [FileRecord] {
        guard !searchText.isEmpty else { return store.files }
        return store.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var recents: [FileRecord] {
        filtered
            .compactMap { record -> (FileRecord, Date)? in
                guard let opened = record.lastOpened else { return nil }
                return (record, opened)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        Group {
            if store.files.isEmpty {
                EmptyStateView(showImporter: $showImporter)
            } else {
                fileList
            }
        }
        .navigationTitle("文件")
        .searchable(text: $searchText, prompt: "搜索文件")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showImporter = true
                } label: {
                    Label("导入文件", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: FileKind.importTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await store.importFiles(from: urls) }
            case .failure(let error):
                store.pendingAlert = "无法导入：\(error.localizedDescription)"
            }
        }
        .navigationDestination(for: FileRecord.self) { record in
            ViewerScreen(record: record)
        }
        .alert("重命名", isPresented: $showRename, presenting: renameTarget) { record in
            TextField("新名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") { store.rename(record, to: renameText) }
        } message: { _ in
            Text("输入新的文件名")
        }
    }

    private var fileList: some View {
        List {
            if !recents.isEmpty {
                Section("最近打开") {
                    ForEach(recents) { record in
                        row(for: record)
                    }
                }
            }
            Section("全部文件") {
                ForEach(filtered) { record in
                    row(for: record)
                }
            } footer: {
                Text("共 \(filtered.count) 个文件")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for record: FileRecord) -> some View {
        NavigationLink(value: record) {
            FileRow(record: record)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(record)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            ShareLink(item: record.url) {
                Label("共享", systemImage: "square.and.arrow.up")
            }
            Button {
                renameTarget = record
                renameText = record.name
                showRename = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.delete(record)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

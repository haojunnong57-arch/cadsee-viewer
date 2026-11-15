import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: LibraryStore
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            Task { await store.importFiles(from: [url]) }
        }
        .alert(
            "导入提示",
            isPresented: Binding(
                get: { store.pendingAlert != nil },
                set: { if !$0 { store.pendingAlert = nil } }
            )
        ) {
            Button("好", role: .cancel) { store.pendingAlert = nil }
        } message: {
            Text(store.pendingAlert ?? "")
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

import SwiftUI

@main
struct CadSeeApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

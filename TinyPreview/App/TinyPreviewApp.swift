import SwiftUI

@main
struct TinyPreviewApp: App {
    var body: some Scene {
        WindowGroup("TinyPreview 设置") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

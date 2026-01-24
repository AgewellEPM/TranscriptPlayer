import SwiftUI

@main
struct TranscriptPlayerApp: App {

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video...") {
                    // Handled by toolbar
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open Transcript...") {
                    // Handled by toolbar
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}

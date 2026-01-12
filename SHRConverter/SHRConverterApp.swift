import SwiftUI
import Combine

// MARK: - Main App Entry Point

@main
struct SHRConverterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Crop") {
                    appState.triggerUndo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appState.canUndo)
            }
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var undoTrigger = false
    @Published var canUndo = false
    
    func triggerUndo() {
        undoTrigger.toggle()
    }
    
    func setCanUndo(_ value: Bool) {
        canUndo = value
    }
}



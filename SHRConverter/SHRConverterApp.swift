import SwiftUI
import Combine

// MARK: - Help Section Enum

enum HelpSection: String, CaseIterable, Identifiable {
    case gettingStarted
    case importingImages
    case browsingImages
    case imageTools
    case paletteEditing
    case exportingImages
    case supportedFormats
    case keyboardShortcuts
    case troubleshooting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .importingImages: return "Importing Images"
        case .browsingImages: return "Browsing Images"
        case .imageTools: return "Image Tools"
        case .paletteEditing: return "Palette Editing"
        case .exportingImages: return "Exporting Images"
        case .supportedFormats: return "Supported Formats"
        case .keyboardShortcuts: return "Keyboard Shortcuts"
        case .troubleshooting: return "Troubleshooting"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "star"
        case .importingImages: return "square.and.arrow.down"
        case .browsingImages: return "photo.on.rectangle"
        case .imageTools: return "wand.and.stars"
        case .paletteEditing: return "paintpalette"
        case .exportingImages: return "square.and.arrow.up"
        case .supportedFormats: return "doc.richtext"
        case .keyboardShortcuts: return "keyboard"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var undoTrigger = false
    @Published var canUndo = false
    @Published var showHelp = false
    @Published var selectedHelpSection: HelpSection = .gettingStarted

    func triggerUndo() {
        undoTrigger.toggle()
    }

    func setCanUndo(_ value: Bool) {
        canUndo = value
    }

    func showHelpSection(_ section: HelpSection) {
        selectedHelpSection = section
        showHelp = true
    }
}

// MARK: - Main App Entry Point

@main
struct SHRConverterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(appState)
                .sheet(isPresented: $appState.showHelp) {
                    HelpView(initialSection: appState.selectedHelpSection)
                        .environmentObject(appState)
                }
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Crop") {
                    appState.triggerUndo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appState.canUndo)
            }

            CommandGroup(replacing: .help) {
                Button("Retro Graphics Converter Help") {
                    appState.selectedHelpSection = .gettingStarted
                    appState.showHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Menu("Quick Help") {
                    Button("Getting Started") {
                        appState.selectedHelpSection = .gettingStarted
                        appState.showHelp = true
                    }
                    Button("Importing Images") {
                        appState.selectedHelpSection = .importingImages
                        appState.showHelp = true
                    }
                    Button("Palette Editing") {
                        appState.selectedHelpSection = .paletteEditing
                        appState.showHelp = true
                    }
                    Button("Exporting Images") {
                        appState.selectedHelpSection = .exportingImages
                        appState.showHelp = true
                    }
                    Button("Supported Formats") {
                        appState.selectedHelpSection = .supportedFormats
                        appState.showHelp = true
                    }
                }

                Divider()

                Button("Keyboard Shortcuts") {
                    appState.selectedHelpSection = .keyboardShortcuts
                    appState.showHelp = true
                }

                Divider()

                Link("Visit GitHub Repository",
                     destination: URL(string: "https://github.com")!)
            }
        }
    }
}



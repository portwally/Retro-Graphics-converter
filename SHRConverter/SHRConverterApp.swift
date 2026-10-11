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

// MARK: - Menu Commands

/// Commands sent from the menu bar (and their keyboard shortcuts) to the main window
enum MenuCommand: Equatable {
    case importFiles
    case export
    case selectAll
    case removeSelected
    case zoomIn
    case zoomOut
    case zoomToFit
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var undoTrigger = false
    @Published var canUndo = false
    @Published var showHelp = false
    @Published var selectedHelpSection: HelpSection = .gettingStarted
    @Published var recentFolders: [URL] = []
    @Published var openFolderRequest: URL? = nil
    /// Set by a menu item; the main window performs it and sets it back to nil
    @Published var pendingCommand: MenuCommand? = nil
    /// Mirrors the main window so menu items can be enabled and disabled
    @Published var hasImages = false
    @Published var hasCurrentImage = false

    private let recentFoldersKey = "RecentFolders"
    private let maxRecentFolders = 10

    init() {
        loadRecentFolders()
    }

    func triggerUndo() {
        undoTrigger.toggle()
    }

    func setCanUndo(_ value: Bool) {
        canUndo = value
    }

    // MARK: - Recent Folders

    func addRecentFolder(_ url: URL) {
        // Remove if already exists
        recentFolders.removeAll { $0 == url }
        // Add to front
        recentFolders.insert(url, at: 0)
        // Limit count
        if recentFolders.count > maxRecentFolders {
            recentFolders = Array(recentFolders.prefix(maxRecentFolders))
        }
        saveRecentFolders()
    }

    func clearRecentFolders() {
        recentFolders.removeAll()
        saveRecentFolders()
    }

    private func loadRecentFolders() {
        if let paths = UserDefaults.standard.stringArray(forKey: recentFoldersKey) {
            recentFolders = paths.compactMap { URL(fileURLWithPath: $0) }
        }
    }

    private func saveRecentFolders() {
        let paths = recentFolders.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentFoldersKey)
    }

    func openRecentFolder(_ url: URL) {
        openFolderRequest = url
    }
}

// MARK: - Main App Entry Point

@main
struct SHRConverterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // A single window: undo, recent folders and help state live in one shared AppState
        Window("Retro Graphics Converter", id: "main") {
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
                Button("Undo") {
                    appState.triggerUndo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appState.canUndo)
            }

            // File menu (this is a single-window app, so there is no New Window item to keep)
            CommandGroup(replacing: .newItem) {
                Button("Import…") {
                    appState.pendingCommand = .importFiles
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Export…") {
                    appState.pendingCommand = .export
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!appState.hasImages)

                Divider()

                Menu("Recent Folders") {
                    if appState.recentFolders.isEmpty {
                        Text("No Recent Folders")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.recentFolders, id: \.path) { url in
                            Button(url.lastPathComponent) {
                                appState.openRecentFolder(url)
                            }
                        }

                        Divider()

                        Button("Clear Recent Folders") {
                            appState.clearRecentFolders()
                        }
                    }
                }
            }

            // Cmd+A is shared with Edit > Select All: while a text field is being edited that
            // item is enabled and takes the key; otherwise it falls through to this one.
            CommandMenu("Image") {
                Button("Select All Images") {
                    appState.pendingCommand = .selectAll
                }
                .keyboardShortcut("a", modifiers: .command)
                .disabled(!appState.hasImages)

                Button("Remove Selected Images") {
                    appState.pendingCommand = .removeSelected
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!appState.hasCurrentImage)
            }

            CommandGroup(before: .toolbar) {
                Button("Zoom In") {
                    appState.pendingCommand = .zoomIn
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!appState.hasCurrentImage)

                Button("Zoom Out") {
                    appState.pendingCommand = .zoomOut
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!appState.hasCurrentImage)

                Button("Fit to Window") {
                    appState.pendingCommand = .zoomToFit
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!appState.hasCurrentImage)

                Divider()
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
                     destination: URL(string: "https://github.com/portwally/Retro-Graphics-converter")!)
            }
        }
    }
}



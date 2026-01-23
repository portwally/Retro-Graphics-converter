import SwiftUI
import AppKit

// MARK: - Screensaver Export Sheet View

struct ScreensaverExportSheet: View {
    @Binding var isPresented: Bool
    let selectedCount: Int
    let onExport: (String, Int, Bool) -> Void  // (name, scale, openSettings)

    @State private var screensaverName: String = "Retro Graphics"
    @State private var upscaleFactor: Int = 4
    @State private var openSystemSettings: Bool = true
    @State private var useScreensaversFolder: Bool = true

    private let defaultFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures")
        .appendingPathComponent("Retro Screensavers")

    private var screensaversFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("Retro Screensavers")
            .appendingPathComponent(screensaverName.isEmpty ? "Retro Graphics" : screensaverName)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            Divider()

            // Screensaver name
            nameSection

            Divider()

            // Scale options
            scaleOptionsSection

            Divider()

            // Options
            optionsSection

            Divider()

            // Info section
            infoSection

            Spacer()

            // Buttons at bottom
            buttonSection
        }
        .padding(20)
        .frame(width: 550, height: 620)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Export as Screensaver")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(selectedCount) image\(selectedCount == 1 ? "" : "s") will be exported")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screensaver Name")
                .font(.headline)

            TextField("Enter a name for your screensaver", text: $screensaverName)
                .textFieldStyle(.roundedBorder)

            Text("Images will be saved to: ~/Pictures/Retro Screensavers/\(screensaverName.isEmpty ? "Retro Graphics" : screensaverName)/")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Scale Options

    private var scaleOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Scale")
                .font(.headline)

            Text("Larger scales look better on high-resolution displays")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Scale factor:", selection: $upscaleFactor) {
                Text("2x").tag(2)
                Text("4x (Recommended)").tag(4)
                Text("8x (High-DPI)").tag(8)
            }
            .pickerStyle(.segmented)

            if let exampleSize = exampleOutputSize {
                Text("Example output: \(exampleSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var exampleOutputSize: String? {
        // Common retro resolutions
        let examples: [(String, Int, Int)] = [
            ("SHR", 320, 200),
            ("C64", 320, 200),
            ("Amiga", 320, 256)
        ]

        let (name, w, h) = examples[0]
        return "\(name) \(w)x\(h) → \(w * upscaleFactor)x\(h * upscaleFactor)"
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Options")
                .font(.headline)

            Toggle(isOn: $openSystemSettings) {
                VStack(alignment: .leading) {
                    Text("Open Screen Saver settings after export")
                    Text("Configure macOS to use your new screensaver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How to use your screensaver:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("1. After export, System Settings will open\n2. Select a photo-based screensaver (e.g., \"Shifting Tiles\")\n3. Click \"Choose Folder\" and select your exported folder\n4. Adjust timing and other options as desired")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                onExport(
                    screensaverName.isEmpty ? "Retro Graphics" : screensaverName,
                    upscaleFactor,
                    openSystemSettings
                )
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "tv")
                    Text("Create Screensaver")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Preview

#Preview {
    ScreensaverExportSheet(
        isPresented: .constant(true),
        selectedCount: 12,
        onExport: { name, scale, openSettings in
            print("Creating screensaver '\(name)' at \(scale)x, openSettings: \(openSettings)")
        }
    )
}

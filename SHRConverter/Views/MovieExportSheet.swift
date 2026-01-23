import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Movie Export Sheet View

struct MovieExportSheet: View {
    @Binding var isPresented: Bool
    let selectedCount: Int
    let onExport: (MovieExportSettings) -> Void

    @State private var movieName: String = "Retro Slideshow"
    @State private var outputFormat: MovieFormat = .mp4
    @State private var duration: Double = 3.0
    @State private var transition: TransitionType = .none
    @State private var upscaleFactor: Int = 4
    @State private var resolution: OutputResolution = .hd1080
    @State private var codec: VideoCodec = .h264

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            Divider()
            nameSection
            Divider()
            formatSection
            Divider()
            codecSection
            Divider()
            timingSection
            Divider()
            scaleSection
            Spacer()
            infoSection
            buttonSection
        }
        .padding(20)
        .frame(width: 550, height: 850)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Export as Movie")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(selectedCount) image\(selectedCount == 1 ? "" : "s") will be included")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movie Name")
                .font(.headline)

            TextField("Enter a name for your movie", text: $movieName)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Format")
                .font(.headline)

            Picker("Format:", selection: $outputFormat) {
                ForEach(MovieFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Text(outputFormat.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timing")
                .font(.headline)

            HStack {
                Text("Duration per image:")
                Picker("", selection: $duration) {
                    Text("1 sec").tag(1.0)
                    Text("2 sec").tag(2.0)
                    Text("3 sec").tag(3.0)
                    Text("5 sec").tag(5.0)
                    Text("10 sec").tag(10.0)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Transition:")
                Spacer()
                Picker("", selection: $transition) {
                    ForEach(TransitionType.allCases, id: \.self) { trans in
                        Text(trans.displayName).tag(trans)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            let totalDuration = Double(selectedCount) * duration
            Text("Total duration: \(formatDuration(totalDuration))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Codec Section

    private var codecSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Codec")
                .font(.headline)

            Picker("Codec:", selection: $codec) {
                ForEach(VideoCodec.allCases, id: \.self) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.segmented)

            Text(codec.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Scale Section

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Size")
                .font(.headline)

            HStack {
                Text("Scale:")
                Picker("", selection: $upscaleFactor) {
                    Text("2x").tag(2)
                    Text("4x").tag(4)
                    Text("8x").tag(8)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Resolution:")
                Picker("", selection: $resolution) {
                    ForEach(OutputResolution.allCases, id: \.self) { res in
                        Text(res.displayName).tag(res)
                    }
                }
                .pickerStyle(.segmented)
            }

            Text("Images will be scaled with nearest-neighbor (pixel-perfect)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)

            Text("MP4/MOV videos can be played in any video player or uploaded to YouTube.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
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
                let settings = MovieExportSettings(
                    name: movieName.isEmpty ? "Retro Slideshow" : movieName,
                    format: outputFormat,
                    duration: duration,
                    transition: transition,
                    scale: upscaleFactor,
                    resolution: resolution,
                    codec: codec
                )
                onExport(settings)
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "film")
                    Text("Create Movie")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Supporting Types

struct MovieExportSettings {
    let name: String
    let format: MovieFormat
    let duration: Double
    let transition: TransitionType
    let scale: Int
    let resolution: OutputResolution
    let codec: VideoCodec
}

enum MovieFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"

    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "MOV"
        }
    }

    var description: String {
        switch self {
        case .mp4: return "H.264 video, universal compatibility"
        case .mov: return "QuickTime format, best for macOS"
        }
    }
}

enum TransitionType: String, CaseIterable {
    case none = "none"
    case random = "random"
    case crossfade = "crossfade"
    case fadeBlack = "fadeBlack"
    case slideLeft = "slideLeft"
    case slideRight = "slideRight"
    case slideUp = "slideUp"
    case slideDown = "slideDown"
    case wipeLeft = "wipeLeft"
    case wipeRight = "wipeRight"
    case zoomIn = "zoomIn"
    case zoomOut = "zoomOut"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .random: return "Random"
        case .crossfade: return "Crossfade"
        case .fadeBlack: return "Fade to Black"
        case .slideLeft: return "Slide Left"
        case .slideRight: return "Slide Right"
        case .slideUp: return "Slide Up"
        case .slideDown: return "Slide Down"
        case .wipeLeft: return "Wipe Left"
        case .wipeRight: return "Wipe Right"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        }
    }

    static var animatedTransitions: [TransitionType] {
        [.crossfade, .fadeBlack, .slideLeft, .slideRight, .slideUp, .slideDown, .wipeLeft, .wipeRight, .zoomIn, .zoomOut]
    }

    static func randomTransition() -> TransitionType {
        animatedTransitions.randomElement() ?? .crossfade
    }
}

enum VideoCodec: String, CaseIterable {
    case h264 = "h264"
    case hevc = "hevc"

    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .hevc: return "H.265 (HEVC)"
        }
    }

    var description: String {
        switch self {
        case .h264: return "Universal compatibility"
        case .hevc: return "Better quality, smaller files"
        }
    }
}

enum OutputResolution: String, CaseIterable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"

    var displayName: String { rawValue }

    var size: CGSize {
        switch self {
        case .hd720: return CGSize(width: 1280, height: 720)
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        }
    }
}

// MARK: - Preview

#Preview {
    MovieExportSheet(
        isPresented: .constant(true),
        selectedCount: 25,
        onExport: { settings in
            print("Exporting movie: \(settings)")
        }
    )
}

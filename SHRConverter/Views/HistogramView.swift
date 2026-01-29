import SwiftUI
import AppKit

// MARK: - Histogram Data Model

struct HistogramData {
    var red: [Int]
    var green: [Int]
    var blue: [Int]
    var luminance: [Int]
    var uniqueColorCount: Int

    static let empty = HistogramData(
        red: Array(repeating: 0, count: 256),
        green: Array(repeating: 0, count: 256),
        blue: Array(repeating: 0, count: 256),
        luminance: Array(repeating: 0, count: 256),
        uniqueColorCount: 0
    )

    var maxValue: Int {
        let maxR = red.max() ?? 0
        let maxG = green.max() ?? 0
        let maxB = blue.max() ?? 0
        let maxL = luminance.max() ?? 0
        return max(maxR, maxG, maxB, maxL)
    }

    static func calculate(from image: NSImage) -> HistogramData {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .empty
        }

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .empty
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return .empty }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var red = Array(repeating: 0, count: 256)
        var green = Array(repeating: 0, count: 256)
        var blue = Array(repeating: 0, count: 256)
        var luminance = Array(repeating: 0, count: 256)
        var uniqueColors = Set<UInt32>()

        for i in 0..<(width * height) {
            let offset = i * 4
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])

            red[r] += 1
            green[g] += 1
            blue[b] += 1

            // Calculate luminance using standard coefficients
            let lum = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
            luminance[min(255, lum)] += 1

            // Track unique colors (pack RGB into 32-bit value)
            let colorKey = UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
            uniqueColors.insert(colorKey)
        }

        return HistogramData(red: red, green: green, blue: blue, luminance: luminance, uniqueColorCount: uniqueColors.count)
    }
}

// MARK: - Channel Selection

enum HistogramChannel: String, CaseIterable {
    case all = "RGB"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case luminance = "Luma"
}

// MARK: - Histogram View

struct HistogramView: View {
    let image: NSImage?
    @State private var histogramData: HistogramData = .empty
    @State private var selectedChannel: HistogramChannel = .all

    var body: some View {
        VStack(spacing: 8) {
            // Channel selector
            Picker("Channel", selection: $selectedChannel) {
                ForEach(HistogramChannel.allCases, id: \.self) { channel in
                    Text(channel.rawValue).tag(channel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Histogram graph
            GeometryReader { geometry in
                Canvas { context, size in
                    drawHistogram(context: context, size: size)
                }
            }
            .frame(height: 100)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Statistics
            if image != nil {
                HStack(spacing: 16) {
                    statisticView(label: "Colors", value: colorCount)
                    statisticView(label: "Mean", value: meanValue)
                    statisticView(label: "Range", value: rangeValue)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: image) { _, newImage in
            calculateHistogram(from: newImage)
        }
        .onAppear {
            calculateHistogram(from: image)
        }
    }

    private func statisticView(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
        }
    }

    private var colorCount: String {
        guard image != nil else { return "-" }
        return "\(histogramData.uniqueColorCount)"
    }

    private var meanValue: String {
        guard histogramData.maxValue > 0 else { return "-" }
        var total = 0
        var count = 0
        for i in 0..<256 {
            total += i * histogramData.luminance[i]
            count += histogramData.luminance[i]
        }
        guard count > 0 else { return "-" }
        return "\(total / count)"
    }

    private var rangeValue: String {
        guard histogramData.maxValue > 0 else { return "-" }
        var minVal = 255
        var maxVal = 0
        for i in 0..<256 {
            if histogramData.luminance[i] > 0 {
                minVal = min(minVal, i)
                maxVal = max(maxVal, i)
            }
        }
        return "\(minVal)-\(maxVal)"
    }

    private func calculateHistogram(from image: NSImage?) {
        guard let img = image else {
            histogramData = .empty
            return
        }

        // Calculate on background thread for large images
        DispatchQueue.global(qos: .userInitiated).async {
            let data = HistogramData.calculate(from: img)
            DispatchQueue.main.async {
                histogramData = data
            }
        }
    }

    private func drawHistogram(context: GraphicsContext, size: CGSize) {
        let maxVal = max(1, histogramData.maxValue)
        let barWidth = size.width / 256

        switch selectedChannel {
        case .all:
            // Draw all channels overlapping with transparency
            drawChannel(context: context, size: size, data: histogramData.red,
                       color: Color.red.opacity(0.5), maxValue: maxVal, barWidth: barWidth)
            drawChannel(context: context, size: size, data: histogramData.green,
                       color: Color.green.opacity(0.5), maxValue: maxVal, barWidth: barWidth)
            drawChannel(context: context, size: size, data: histogramData.blue,
                       color: Color.blue.opacity(0.5), maxValue: maxVal, barWidth: barWidth)

        case .red:
            drawChannel(context: context, size: size, data: histogramData.red,
                       color: Color.red, maxValue: maxVal, barWidth: barWidth)

        case .green:
            drawChannel(context: context, size: size, data: histogramData.green,
                       color: Color.green, maxValue: maxVal, barWidth: barWidth)

        case .blue:
            drawChannel(context: context, size: size, data: histogramData.blue,
                       color: Color.blue, maxValue: maxVal, barWidth: barWidth)

        case .luminance:
            drawChannel(context: context, size: size, data: histogramData.luminance,
                       color: Color.gray, maxValue: maxVal, barWidth: barWidth)
        }
    }

    private func drawChannel(context: GraphicsContext, size: CGSize, data: [Int],
                            color: Color, maxValue: Int, barWidth: CGFloat) {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: size.height))

        for i in 0..<256 {
            let height = CGFloat(data[i]) / CGFloat(maxValue) * size.height
            let x = CGFloat(i) * barWidth
            path.addLine(to: CGPoint(x: x, y: size.height - height))
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }
}

// MARK: - Histogram Popover Button

struct HistogramButton: View {
    let image: NSImage?
    @State private var showHistogram = false

    var body: some View {
        Button(action: { showHistogram.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showHistogram ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .foregroundColor(image == nil ? Color(NSColor.tertiaryLabelColor) :
                                    (showHistogram ? .accentColor : Color(NSColor.labelColor)))

                Text("Histogram")
                    .font(.system(size: 9))
                    .foregroundColor(image == nil ? Color(NSColor.tertiaryLabelColor) :
                                    (showHistogram ? .accentColor : Color(NSColor.secondaryLabelColor)))
            }
        }
        .buttonStyle(.plain)
        .disabled(image == nil)
        .help("Show Color Histogram")
        .popover(isPresented: $showHistogram, arrowEdge: .bottom) {
            HistogramView(image: image)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        HistogramView(image: nil)

        HistogramButton(image: nil)
    }
    .padding()
}

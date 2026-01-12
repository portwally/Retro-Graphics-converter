import SwiftUI
import AppKit

// MARK: - Image Crop Tool

struct ImageCropView: View {
    let image: NSImage
    let onCrop: (NSImage) -> Void
    let onCopy: (NSImage) -> Void
    let onCancel: () -> Void
    
    @State private var selectionRect: CGRect = .zero
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    private let minSelectionSize: CGFloat = 10
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Crop Tool").font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Canvas with image and selection box
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.9)
                    
                    // The image
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .frame(
                            width: image.size.width * imageScale,
                            height: image.size.height * imageScale
                        )
                        .offset(imageOffset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    imageScale = max(0.1, min(value, 10.0))
                                }
                        )
                    
                    // Selection overlay
                    if selectionRect != .zero {
                        SelectionOverlay(rect: selectionRect, imageSize: image.size, imageScale: imageScale, imageOffset: imageOffset)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStart = value.location
                            }
                            
                            let currentPoint = value.location
                            let centerX = geometry.size.width / 2
                            let centerY = geometry.size.height / 2
                            
                            // Calculate image bounds in view coordinates
                            let imageWidth = image.size.width * imageScale
                            let imageHeight = image.size.height * imageScale
                            let imageLeft = centerX + imageOffset.width - imageWidth / 2
                            let imageTop = centerY + imageOffset.height - imageHeight / 2
                            
                            // Convert view coordinates to image coordinates
                            let x1 = (min(dragStart.x, currentPoint.x) - imageLeft) / imageScale
                            let y1 = (min(dragStart.y, currentPoint.y) - imageTop) / imageScale
                            let x2 = (max(dragStart.x, currentPoint.x) - imageLeft) / imageScale
                            let y2 = (max(dragStart.y, currentPoint.y) - imageTop) / imageScale
                            
                            // Clamp to image bounds
                            let clampedX1 = max(0, min(x1, image.size.width))
                            let clampedY1 = max(0, min(y1, image.size.height))
                            let clampedX2 = max(0, min(x2, image.size.width))
                            let clampedY2 = max(0, min(y2, image.size.height))
                            
                            selectionRect = CGRect(
                                x: clampedX1,
                                y: clampedY1,
                                width: clampedX2 - clampedX1,
                                height: clampedY2 - clampedY1
                            )
                        }
                        .onEnded { _ in
                            isDragging = false
                            // Remove selection if too small
                            if selectionRect.width < minSelectionSize || selectionRect.height < minSelectionSize {
                                selectionRect = .zero
                            }
                        }
                )
            }
            
            Divider()
            
            // Toolbar
            HStack(spacing: 12) {
                // Selection info
                if selectionRect != .zero {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selection: \(Int(selectionRect.width))×\(Int(selectionRect.height))")
                            .font(.caption)
                            .monospacedDigit()
                        Text("Position: x:\(Int(selectionRect.origin.x)), y:\(Int(selectionRect.origin.y))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                } else {
                    Text("Drag to select an area")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Zoom controls
                HStack(spacing: 6) {
                    Button(action: { imageScale = max(0.1, imageScale / 1.5) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom Out")
                    
                    Text("\(Int(imageScale * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 50)
                    
                    Button(action: { imageScale = min(10.0, imageScale * 1.5) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom In")
                    
                    Button(action: {
                        imageScale = 1.0
                        imageOffset = .zero
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset View")
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(height: 20)
                
                // Action buttons
                Button("Clear Selection") {
                    selectionRect = .zero
                }
                .disabled(selectionRect == .zero)
                
                Button("Copy") {
                    if let croppedImage = cropImage(image: image, rect: selectionRect) {
                        onCopy(croppedImage)
                    }
                }
                .disabled(selectionRect == .zero)
                .help("Copy selected area to clipboard")
                
                Button("Crop & Replace") {
                    if let croppedImage = cropImage(image: image, rect: selectionRect) {
                        onCrop(croppedImage)
                    }
                }
                .disabled(selectionRect == .zero)
                .help("Crop image to selected area")
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Crop Function
    
    private func cropImage(image: NSImage, rect: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Create crop rectangle (CGImage uses flipped coordinates)
        let cropRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return NSImage(cgImage: croppedCGImage, size: NSSize(
            width: croppedCGImage.width,
            height: croppedCGImage.height
        ))
    }
}

// MARK: - Selection Overlay

struct SelectionOverlay: View {
    let rect: CGRect
    let imageSize: CGSize
    let imageScale: CGFloat
    let imageOffset: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            let imageWidth = imageSize.width * imageScale
            let imageHeight = imageSize.height * imageScale
            let imageLeft = centerX + imageOffset.width - imageWidth / 2
            let imageTop = centerY + imageOffset.height - imageHeight / 2
            
            // Convert image coordinates to view coordinates
            let viewX = imageLeft + rect.origin.x * imageScale
            let viewY = imageTop + rect.origin.y * imageScale
            let viewWidth = rect.width * imageScale
            let viewHeight = rect.height * imageScale
            
            ZStack {
                // Dimmed overlay outside selection
                GeometryReader { geo in
                    Path { path in
                        // Outer rectangle (full view)
                        path.addRect(CGRect(origin: .zero, size: geo.size))
                        // Inner rectangle (selection) - subtract
                        path.addRect(CGRect(x: viewX, y: viewY, width: viewWidth, height: viewHeight))
                    }
                    .fill(style: FillStyle(eoFill: true))
                    .foregroundColor(Color.black.opacity(0.5))
                }
                
                // Selection border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: viewWidth, height: viewHeight)
                    .position(x: viewX + viewWidth / 2, y: viewY + viewHeight / 2)
                
                // Corner handles
                ForEach(0..<4) { corner in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .position(
                            x: viewX + (corner % 2 == 0 ? 0 : viewWidth),
                            y: viewY + (corner < 2 ? 0 : viewHeight)
                        )
                }
                
                // Dimension labels
                Text("\(Int(rect.width))×\(Int(rect.height))")
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .position(x: viewX + viewWidth / 2, y: viewY - 15)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImageCropView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
        onCrop: { _ in },
        onCopy: { _ in },
        onCancel: {}
    )
}

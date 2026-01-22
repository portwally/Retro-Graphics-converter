import SwiftUI

// MARK: - Image Thumbnail View

struct ImageThumbnailView: View {
    let item: ImageItem
    let isSelected: Bool
    let isChecked: Bool
    var thumbnailSize: CGFloat = 80
    let onSelect: () -> Void
    let onToggleCheck: () -> Void

    private var thumbnailWidth: CGFloat { thumbnailSize * 1.5 }
    private var thumbnailHeight: CGFloat { thumbnailSize * 1.125 }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: item.image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture { onSelect() }

                Button(action: { onToggleCheck() }) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isChecked ? .blue : .white)
                        .background(
                            Circle()
                                .fill(isChecked ? Color.white : Color.black.opacity(0.3))
                                .frame(width: 22, height: 22)
                        )
                }
                .buttonStyle(.plain)
                .padding(6)
            }

            Text(item.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: thumbnailWidth)

            Text(item.type.displayName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

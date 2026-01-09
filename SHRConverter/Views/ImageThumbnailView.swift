import SwiftUI

// MARK: - Image Thumbnail View

struct ImageThumbnailView: View {
    let item: ImageItem
    let isSelected: Bool
    let isChecked: Bool
    let onSelect: () -> Void
    let onToggleCheck: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: item.image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 120, height: 90)
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
                .frame(width: 120)
            
            Text(item.type.displayName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

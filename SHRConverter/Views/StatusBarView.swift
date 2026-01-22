import SwiftUI

// MARK: - Status Bar View

struct StatusBarView: View {
    let importedCount: Int
    let selectedCount: Int
    let removedCount: Int
    let exportedCount: Int

    var body: some View {
        HStack(spacing: 16) {
            StatusItem(
                icon: "square.and.arrow.down",
                label: "Imported",
                count: importedCount
            )

            Divider()
                .frame(height: 12)

            StatusItem(
                icon: "checkmark.circle",
                label: "Selected",
                count: selectedCount
            )

            Divider()
                .frame(height: 12)

            StatusItem(
                icon: "trash",
                label: "Removed",
                count: removedCount
            )

            Divider()
                .frame(height: 12)

            StatusItem(
                icon: "square.and.arrow.up",
                label: "Exported",
                count: exportedCount
            )

            Spacer()
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Status Item

private struct StatusItem: View {
    let icon: String
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .fontWeight(.medium)
            Text(label)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        StatusBarView(
            importedCount: 42,
            selectedCount: 5,
            removedCount: 2,
            exportedCount: 10
        )

        StatusBarView(
            importedCount: 0,
            selectedCount: 0,
            removedCount: 0,
            exportedCount: 0
        )
    }
}

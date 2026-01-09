import SwiftUI

// MARK: - Disk Catalog Browser View

struct DiskCatalogBrowserView: View {
    let catalog: DiskCatalog
    let onImport: ([DiskCatalogEntry]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedEntries: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var showImagesOnly: Bool = false
    @State private var expandAllTrigger: Bool = false
    @State private var expandAllToggleId = UUID()
    
    var filteredEntries: [DiskCatalogEntry] {
        var entries = showImagesOnly || !searchText.isEmpty ? catalog.allEntries : catalog.entries
        if !searchText.isEmpty {
            entries = entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.typeDescription.localizedCaseInsensitiveContains(searchText) }
        }
        if showImagesOnly { entries = entries.filter { $0.isImage } }
        return entries
    }
    
    var selectedCount: Int { selectedEntries.count }
    var selectedImagesCount: Int { catalog.allEntries.filter { selectedEntries.contains($0.id) && $0.isImage }.count }

    func toggleSelection(_ entry: DiskCatalogEntry) {
        if selectedEntries.contains(entry.id) { selectedEntries.remove(entry.id) } else { selectedEntries.insert(entry.id) }
    }
    func isSelected(entry: DiskCatalogEntry) -> Bool { selectedEntries.contains(entry.id) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💾 \(catalog.diskName)").font(.title2).fontWeight(.bold)
                        Text("(\(catalog.diskFormat))").font(.subheadline).foregroundColor(.secondary)
                    }
                    HStack(spacing: 16) {
                        Label("\(catalog.totalFiles) files", systemImage: "doc.text").font(.caption).foregroundColor(.secondary)
                        Label("\(catalog.imageFiles) images", systemImage: "photo").font(.caption).foregroundColor(.blue)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(catalog.diskSize), countStyle: .file)).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onCancel) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }.buttonStyle(.plain)
            }.padding().background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Toolbar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText).textFieldStyle(.plain)
                    if !searchText.isEmpty { Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }.buttonStyle(.plain) }
                }.padding(6).background(Color(NSColor.textBackgroundColor)).cornerRadius(6).frame(width: 250)
                
                Toggle(isOn: $showImagesOnly) { HStack(spacing: 4) { Image(systemName: "photo"); Text("Images Only") } }.toggleStyle(.checkbox)
                Spacer()
                Button("Select All Images") { selectedEntries = Set(catalog.allEntries.filter { $0.isImage }.map { $0.id }) }
                Button("Clear Selection") { selectedEntries.removeAll() }
                Button("Expand All") { expandAllTrigger = true; expandAllToggleId = UUID() }
                Button("Collapse All") { expandAllTrigger = false; expandAllToggleId = UUID() }
            }.padding(.horizontal).padding(.vertical, 8).background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Table
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        CatalogEntryRow(entry: entry, isSelected: isSelected, onToggle: toggleSelection, level: 0, expandAllTrigger: expandAllTrigger)
                    }
                }
            }.id(expandAllToggleId)
            
            Divider()
            
            // Footer
            HStack {
                HStack(spacing: 16) {
                    Text("\(selectedCount) selected").foregroundColor(.secondary)
                    if selectedImagesCount > 0 { Text("(\(selectedImagesCount) images)").foregroundColor(.blue).fontWeight(.medium) }
                }
                Spacer()
                Button("Cancel") { onCancel() }.keyboardShortcut(.cancelAction)
                Button("Export Files") { exportSelectedFiles() }.disabled(selectedCount == 0)
                Button("Import Selected") { onImport(catalog.allEntries.filter { selectedEntries.contains($0.id) }) }.keyboardShortcut(.defaultAction).disabled(selectedCount == 0)
            }.padding().background(Color(NSColor.controlBackgroundColor))
        }.frame(width: 900, height: 600).onAppear { selectedEntries = [] }
    }
    
    func exportSelectedFiles() {
        let entriesToExport = catalog.allEntries.filter { selectedEntries.contains($0.id) }
        guard !entriesToExport.isEmpty else { return }
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let exportFolder = downloadsURL.appendingPathComponent("\(catalog.diskName)_export_\(dateFormatter.string(from: Date()))")
        
        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            for entry in entriesToExport where !entry.isDirectory {
                var filename = entry.name
                if !filename.contains(".") {
                    switch entry.fileType {
                    case 0x00, 0x01: filename += ".txt"
                    case 0x02: filename += ".bas"
                    case 0x04, 0x06: filename += ".bin"
                    case 0xFA, 0xFC: filename += ".bas"
                    default: filename += ".dat"
                    }
                }
                try entry.data.write(to: exportFolder.appendingPathComponent(filename))
            }
            NSWorkspace.shared.activateFileViewerSelecting([exportFolder])
        } catch { }
    }
}

// MARK: - Catalog Entry Row

struct CatalogEntryRow: View {
    let entry: DiskCatalogEntry
    let isSelected: (DiskCatalogEntry) -> Bool
    let onToggle: (DiskCatalogEntry) -> Void
    let level: Int
    let expandAllTrigger: Bool
    
    @State private var isExpanded: Bool
    
    init(entry: DiskCatalogEntry, isSelected: @escaping (DiskCatalogEntry) -> Bool, onToggle: @escaping (DiskCatalogEntry) -> Void, level: Int, expandAllTrigger: Bool) {
        self.entry = entry; self.isSelected = isSelected; self.onToggle = onToggle; self.level = level; self.expandAllTrigger = expandAllTrigger
        _isExpanded = State(initialValue: expandAllTrigger)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if level > 0 { ForEach(0..<level, id: \.self) { _ in Text("  ") }; Text("└─").font(.caption).foregroundColor(.secondary) }
                
                Button(action: { onToggle(entry) }) {
                    Image(systemName: isSelected(entry) ? "checkmark.square.fill" : "square").foregroundColor(isSelected(entry) ? .blue : .secondary)
                }.buttonStyle(.plain).frame(width: 30)
                
                if entry.isDirectory && entry.children != nil && !entry.children!.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.caption).foregroundColor(.secondary).frame(width: 20, height: 20).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                
                Text(entry.icon).font(.title3)
                Text(entry.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).fontWeight(entry.isDirectory ? .semibold : .regular)
                Text(entry.typeDescription).font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                Text(entry.sizeString).font(.caption).monospacedDigit().foregroundColor(.secondary).frame(width: 80, alignment: .trailing)
                if let loadAddr = entry.loadAddress { Text(String(format: "$%04X", loadAddr)).font(.caption).monospacedDigit().foregroundColor(.secondary).frame(width: 80, alignment: .trailing) }
                else { Text("-").font(.caption).foregroundColor(.secondary).frame(width: 80, alignment: .trailing) }
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(isSelected(entry) ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle()).onTapGesture { onToggle(entry) }
            
            if entry.isDirectory && isExpanded, let children = entry.children {
                ForEach(children) { child in
                    CatalogEntryRow(entry: child, isSelected: isSelected, onToggle: onToggle, level: level + 1, expandAllTrigger: expandAllTrigger)
                }
            }
        }.onChange(of: expandAllTrigger) { newValue in isExpanded = newValue }
    }
}

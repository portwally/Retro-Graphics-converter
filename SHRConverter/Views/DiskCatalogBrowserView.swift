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

            // Column Headers
            HStack(spacing: 8) {
                Text("").frame(width: 30)  // Checkbox column
                Text("").frame(width: 24)  // Icon column
                Text("Name").font(.caption).fontWeight(.semibold).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text("Type").font(.caption).fontWeight(.semibold).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                Text("Size").font(.caption).fontWeight(.semibold).foregroundColor(.secondary).frame(width: 80, alignment: .trailing)
                Text("AuxType").font(.caption).fontWeight(.semibold).foregroundColor(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))

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
        let safeDiskName = catalog.diskName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let exportFolder = downloadsURL.appendingPathComponent("\(safeDiskName)_export_\(dateFormatter.string(from: Date()))")
        
        var failures: [String] = []
        var usedPaths = Set<String>()

        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        } catch {
            showExportAlert(title: "Could not create the export folder", text: error.localizedDescription)
            return
        }

        for entry in entriesToExport where !entry.isDirectory {
            // FAT disks report files as "FOLDER/FILE"; keep that structure, but never let a
            // name climb out of the export folder or contain characters Finder rejects
            let components = entry.name.split(separator: "/").map { part -> String in
                let cleaned = part.replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespaces)
                return (cleaned.isEmpty || cleaned == "." || cleaned == "..") ? "_" : cleaned
            }
            var filename = components.last ?? "_"
            if !filename.contains(".") {
                filename += "." + entry.defaultExportExtension
            }

            var folder = exportFolder
            for part in components.dropLast() { folder.appendPathComponent(part) }

            // Two entries can share a name (different user areas, case-insensitive volume)
            var target = folder.appendingPathComponent(filename)
            var counter = 2
            while usedPaths.contains(target.path.lowercased()) {
                let base = (filename as NSString).deletingPathExtension
                let ext = (filename as NSString).pathExtension
                target = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)")
                counter += 1
            }
            usedPaths.insert(target.path.lowercased())

            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try entry.data.write(to: target)
            } catch {
                failures.append("\(entry.name): \(error.localizedDescription)")
            }
        }

        NSWorkspace.shared.activateFileViewerSelecting([exportFolder])

        if !failures.isEmpty {
            let shown = failures.prefix(8).joined(separator: "\n")
            let more = failures.count > 8 ? "\n…and \(failures.count - 8) more" : ""
            showExportAlert(title: "\(failures.count) file(s) could not be exported", text: shown + more)
        }
    }

    private func showExportAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        }.onChange(of: expandAllTrigger) { _, newValue in isExpanded = newValue }
    }
}

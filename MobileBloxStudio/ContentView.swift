import SwiftUI
import UniformTypeIdentifiers

private enum StudioStyle {
    static let background = Color(red: 0.055, green: 0.045, blue: 0.09)
    static let panel = Color(red: 0.105, green: 0.085, blue: 0.16)
    static let raised = Color(red: 0.15, green: 0.12, blue: 0.22)
    static let purple = Color(red: 0.66, green: 0.43, blue: 1.0)
    static let muted = Color(red: 0.63, green: 0.59, blue: 0.71)
}

private struct StudioScript: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var contents: String
    var modifiedAt: Date

    init(name: String, contents: String = "") {
        id = UUID()
        self.name = name
        self.contents = contents
        modifiedAt = .now
    }
}

@MainActor
private final class ScriptLibrary: ObservableObject {
    @Published private(set) var scripts: [StudioScript] = []
    private let folder: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("StudioScripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    func create() -> UUID {
        let script = StudioScript(name: "Untitled.lua", contents: "-- New local script\n")
        scripts.insert(script, at: 0)
        save(script)
        return script.id
    }

    func update(_ script: StudioScript) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        var changed = script
        changed.modifiedAt = .now
        scripts[index] = changed
        save(changed)
    }

    func delete(_ script: StudioScript) {
        scripts.removeAll { $0.id == script.id }
        try? FileManager.default.removeItem(at: fileURL(for: script))
    }

    func importFile(from url: URL) throws -> UUID {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }
        let contents = try String(contentsOf: url, encoding: .utf8)
        let imported = StudioScript(name: url.lastPathComponent, contents: contents)
        scripts.insert(imported, at: 0)
        save(imported)
        return imported.id
    }

    func script(id: UUID) -> StudioScript? {
        scripts.first { $0.id == id }
    }

    private func fileURL(for script: StudioScript) -> URL {
        folder.appendingPathComponent("\(script.id.uuidString).json")
    }

    private func save(_ script: StudioScript) {
        guard let data = try? JSONEncoder().encode(script) else { return }
        try? data.write(to: fileURL(for: script), options: .atomic)
    }

    private func load() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return }

        scripts = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(StudioScript.self, from: data)
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

struct ContentView: View {
    @StateObject private var library = ScriptLibrary()
    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingNewName = false
    @State private var newName = ""
    @State private var exportScript: ScriptDocument?
    @State private var showingExporter = false
    @State private var showingDeleteConfirmation = false
    @State private var scriptToDelete: StudioScript?
    @State private var showingInstallGuide = false
    @State private var fileFilter = "All"

    private var projectGroups: [(String, [StudioScript])] {
        let luaFiles = filteredScripts.filter { $0.name.lowercased().hasSuffix(".lua") }
        let textFiles = filteredScripts.filter { !$0.name.lowercased().hasSuffix(".lua") }
        return [("LUA PROJECT", luaFiles), ("TEXT PROJECT", textFiles)]
            .filter { !$0.1.isEmpty }
    }

    private var filteredScripts: [StudioScript] {
        let searched = searchText.isEmpty
            ? library.scripts
            : library.scripts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        switch fileFilter {
        case "Lua":
            return searched.filter { $0.name.lowercased().hasSuffix(".lua") }
        case "Text":
            return searched.filter { !$0.name.lowercased().hasSuffix(".lua") }
        default:
            return searched
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioStyle.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(StudioStyle.muted)
                        TextField("Search your files", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(13)
                    .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 18)
                    .padding(.top, 20)

                    libraryHeader
                    fileBrowserFilters

                    if filteredScripts.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(projectGroups, id: \.0) { group in
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(group.0)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .tracking(1.4)
                                            .foregroundStyle(StudioStyle.purple)
                                            .padding(.horizontal, 3)

                                        ForEach(group.1) { script in
                                            scriptRow(script)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                        }
                    }

                    footer
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingInstallGuide) { InstallGuideView() }
            .sheet(item: selectedScriptBinding) { script in
                EditorView(script: script, library: library) { updated in
                    selectedID = updated.id
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText, .sourceCode, .text],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first,
                      let id = try? library.importFile(from: url) else { return }
                selectedID = id
            }
            .alert("New file name", isPresented: $showingNewName) {
                TextField("Example.lua", text: $newName)
                Button("Create") {
                    let id = library.create()
                    if let created = library.script(id: id) {
                        var renamed = created
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { renamed.name = trimmed }
                        library.update(renamed)
                    }
                    selectedID = id
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
            .confirmationDialog(
                "Delete this file?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let scriptToDelete { library.delete(scriptToDelete) }
                }
            }
        }
        .tint(StudioStyle.purple)
    }

    private var selectedScriptBinding: Binding<StudioScript?> {
        Binding(
            get: { selectedID.flatMap { library.script(id: $0) } },
            set: { if $0 == nil { selectedID = nil } }
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(StudioStyle.purple)
                    Text("MOBILEBLOX")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(StudioStyle.muted)
                }
                Text("Studio")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                showingImporter = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 14))
            }

            Button {
                showingInstallGuide = true
            } label: {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 14))
            }

            Button {
                newName = "Untitled.lua"
                showingNewName = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(StudioStyle.purple, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var libraryHeader: some View {
        HStack {
            Text("YOUR LIBRARY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(StudioStyle.muted)
            Spacer()
            Text("\(library.scripts.count) FILES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(StudioStyle.purple)
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
        .padding(.bottom, 12)
    }

    private var fileBrowserFilters: some View {
        HStack(spacing: 8) {
            ForEach(["All", "Lua", "Text"], id: \.self) { filter in
                Button {
                    fileFilter = filter
                } label: {
                    Text(filter)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(fileFilter == filter ? .white : StudioStyle.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(fileFilter == filter ? StudioStyle.purple.opacity(0.8) : StudioStyle.panel, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(StudioStyle.purple.opacity(0.8))
            Text(searchText.isEmpty ? "Your workspace is empty" : "No matching files")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(searchText.isEmpty
                 ? "Create a file or import a text script to get started."
                 : "Try another file name.")
                .font(.system(size: 13))
                .foregroundStyle(StudioStyle.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scriptRow(_ script: StudioScript) -> some View {
        Button {
            selectedID = script.id
        } label: {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(StudioStyle.purple.opacity(0.16))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "doc.text")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(StudioStyle.purple)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(script.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Edited \(script.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(StudioStyle.muted)
                }

                Spacer()

                Menu {
                    Button {
                        exportScript = ScriptDocument(text: script.contents)
                        showingExporter = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        scriptToDelete = script
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(StudioStyle.muted)
                        .frame(width: 36, height: 40)
                        .contentShape(Rectangle())
                }
            }
            .padding(13)
            .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(.white.opacity(0.045), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportScript,
            contentType: .plainText,
            defaultFilename: script.name
        ) { _ in }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("LOCAL WORKSPACE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
            Spacer()
            Text("TEXT EDITOR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(StudioStyle.muted)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(StudioStyle.panel.opacity(0.75))
    }
}

private struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var script: StudioScript
    @State private var showingExport = false
    @State private var document: ScriptDocument
    @ObservedObject var library: ScriptLibrary
    var onSave: (StudioScript) -> Void

    init(script: StudioScript, library: ScriptLibrary, onSave: @escaping (StudioScript) -> Void) {
        _script = State(initialValue: script)
        _document = State(initialValue: ScriptDocument(text: script.contents))
        self.library = library
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioStyle.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundStyle(StudioStyle.purple)
                        Text("SOURCE EDITOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(StudioStyle.muted)
                        Spacer()
                        Text("LUA / TEXT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(StudioStyle.purple)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)

                    TextField("File name", text: $script.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(13)
                        .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)

                    EditorCodeSurface(contents: $script.contents)
                        .padding(8)
                        .background(StudioStyle.panel, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 12)

                    HStack {
                        Text("\(script.contents.split(separator: "\n", omittingEmptySubsequences: false).count) LINES")
                        Spacer()
                        Text("\(script.contents.utf8.count) BYTES")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(StudioStyle.muted)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(StudioStyle.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = script.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { script.name = trimmed }
                        library.update(script)
                        onSave(script)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        document = ScriptDocument(text: script.contents)
                        showingExport = true
                    } label: {
                        Label("Export text", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExport,
                document: document,
                contentType: .plainText,
                defaultFilename: script.name
            ) { _ in }
        }
        .tint(StudioStyle.purple)
    }
}

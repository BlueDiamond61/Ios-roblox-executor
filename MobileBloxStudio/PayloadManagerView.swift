import SwiftUI
import UniformTypeIdentifiers

private struct LocalPayload: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var source: String
    var modifiedAt: Date

    init(name: String, source: String = "-- Local Luau file\n") {
        id = UUID()
        self.name = name
        self.source = source
        modifiedAt = .now
    }
}

struct PayloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var payloads: [LocalPayload] = []
    @State private var selectedID: UUID?
    @State private var draftName = ""
    @State private var draftSource = ""
    @State private var showingEditor = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = ScriptDocument()
    @State private var exportName = "Payload.lua"
    @State private var searchText = ""
    @State private var executorSource = "-- MobileBlox Studio\n-- Local script workspace\n\nprint(\"Hello from the local editor\")\n"
    @State private var executorName = "Workspace.lua"
    @State private var consoleOutput = "Ready. Scripts are stored locally.\n"
    @State private var isRunning = false

    private let accent = Color(red: 0.68, green: 0.46, blue: 1.0)
    private let background = Color(red: 0.055, green: 0.045, blue: 0.09)
    private let panel = Color(red: 0.12, green: 0.095, blue: 0.18)

    private var storageURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("LocalPayloads.json")
    }

    private var visiblePayloads: [LocalPayload] {
        guard !searchText.isEmpty else { return payloads }
        return payloads.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                VStack(spacing: 14) {
                    executorPanel

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search local files", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(13)
                    .background(panel, in: RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal)

                    HStack {
                        Text("LOCAL FILES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(payloads.count) FILES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal)

                    if visiblePayloads.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(accent)
                            Text(searchText.isEmpty ? "No local files" : "No matching files")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Create a Luau file or import a .lua or .txt file.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(visiblePayloads) { item in
                                Button {
                                    open(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 18))
                                            .foregroundStyle(accent)
                                            .frame(width: 38, height: 38)
                                            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            Text("Modified \(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(panel)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        remove(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        export(item)
                                    } label: {
                                        Label("Export", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(accent)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.top, 14)
            }
            .navigationTitle("Payload Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button {
                        draftName = "Untitled.lua"
                        draftSource = "-- Local Luau file\n"
                        selectedID = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                editorSheet
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText, .sourceCode, .text],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer {
                        if access { url.stopAccessingSecurityScopedResource() }
                    }
                    guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    payloads.insert(LocalPayload(name: url.lastPathComponent, source: source), at: 0)
                }
                persist()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .plainText,
                defaultFilename: exportName
            ) { _ in }
            .onAppear(perform: load)
        }
        .tint(accent)
    }

    private var executorPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill").foregroundStyle(accent)
                    Text("EXECUTOR WORKSPACE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(isRunning ? Color.orange : Color.green).frame(width: 6, height: 6)
                    Text(isRunning ? "BUSY" : "LOCAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Script name", text: $executorName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(10)
                .background(background, in: RoundedRectangle(cornerRadius: 9))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $executorSource)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(5)
                if executorSource.isEmpty {
                    Text("-- Write a local Lua/Luau script")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 170, maxHeight: 230)
            .background(background, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(accent.opacity(0.25), lineWidth: 1))

            HStack(spacing: 8) {
                Button {
                    isRunning = false
                    consoleOutput += "\n[Studio] Runtime is not connected. Nothing was executed.\n"
                } label: {
                    Label("Execute", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(accent, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)

                Button {
                    isRunning = false
                    consoleOutput += "\n[Studio] Stop requested. No runtime session is active.\n"
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(background, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    consoleOutput = "Console cleared.\n"
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 42, height: 40)
                        .background(background, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("CONSOLE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(accent)
                    Spacer()
                    Text("OUTPUT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(consoleOutput)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 62)
                .padding(9)
                .background(background, in: RoundedRectangle(cornerRadius: 9))
            }

            Text("UI preview only • A sandboxed Lua runtime must be added before scripts can execute.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .background(panel, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 14)
    }

    private var editorSheet: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                VStack(spacing: 12) {
                    TextField("File name", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal)

                    TextEditor(text: $draftSource)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(panel, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
                .padding(.top, 14)
            }
            .navigationTitle("Edit local file")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingEditor = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: saveDraft)
                        .fontWeight(.bold)
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(accent)
    }

    private func open(_ item: LocalPayload) {
        selectedID = item.id
        draftName = item.name
        draftSource = item.source
        showingEditor = true
    }

    private func saveDraft() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let selectedID, let index = payloads.firstIndex(where: { $0.id == selectedID }) {
            payloads[index].name = name
            payloads[index].source = draftSource
            payloads[index].modifiedAt = .now
        } else {
            payloads.insert(LocalPayload(name: name, source: draftSource), at: 0)
        }

        persist()
        showingEditor = false
    }

    private func remove(_ item: LocalPayload) {
        payloads.removeAll { $0.id == item.id }
        persist()
    }

    private func export(_ item: LocalPayload) {
        exportDocument = ScriptDocument(text: item.source)
        exportName = item.name
        showingExporter = true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(payloads) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([LocalPayload].self, from: data) else { return }
        payloads = saved.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

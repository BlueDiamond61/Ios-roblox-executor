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
    @State private var isExecutorExpanded = true
    @State private var isLoadstringEnabled = false

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
        Group {
            if isExecutorExpanded {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text("Δ")
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(red: 0.20, green: 0.39, blue: 0.78), in: RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("MOBILEBLOX")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.5)
                                .foregroundStyle(.white)
                            Text("SCRIPT WORKSPACE")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("LOCAL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                isExecutorExpanded = false
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Minimize executor")
                    }
                    .padding(12)
                    .background(Color(red: 0.105, green: 0.105, blue: 0.13))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(Color(red: 0.40, green: 0.62, blue: 1.0))
                            TextField("Workspace.lua", text: $executorName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 35)
                        .background(Color(red: 0.075, green: 0.075, blue: 0.095), in: RoundedRectangle(cornerRadius: 7))

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $executorSource)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(red: 0.88, green: 0.89, blue: 0.93))
                                .scrollContentBackground(.hidden)
                                .padding(5)

                            if executorSource.isEmpty {
                                Text("-- Paste or write a local Lua/Luau script...")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 13)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(minHeight: 145, maxHeight: 205)
                        .background(Color(red: 0.065, green: 0.065, blue: 0.085), in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }

                        HStack(spacing: 8) {
                            Toggle(isOn: $isLoadstringEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Loadstring")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Local sandbox option")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.30, green: 0.52, blue: 0.95)))
                            .scaleEffect(0.82, anchor: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 7) {
                            Button {
                                isRunning = false
                                consoleOutput += "\n[Studio] Lua runtime is not connected. No script was executed.\n"
                                if isLoadstringEnabled {
                                    consoleOutput += "[Studio] Loadstring is a UI preference only until the local sandbox is integrated.\n"
                                }
                            } label: {
                                Label("Execute", systemImage: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 37)
                                    .background(Color(red: 0.25, green: 0.46, blue: 0.88), in: RoundedRectangle(cornerRadius: 7))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                executorSource = ""
                            } label: {
                                Label("Clear", systemImage: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 37)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                let name = executorName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                payloads.insert(LocalPayload(name: name, source: executorSource), at: 0)
                                persist()
                                consoleOutput += "\n[Studio] Saved \(name) to the local library.\n"
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 39, height: 37)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Save script to local library")
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("CONSOLE")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundStyle(Color(red: 0.48, green: 0.66, blue: 1.0))
                                Spacer()
                                Button("Clear output") {
                                    consoleOutput = "Console cleared.\n"
                                }
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                            }

                            ScrollView {
                                Text(consoleOutput)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(height: 52)
                            .padding(8)
                            .background(Color(red: 0.065, green: 0.065, blue: 0.085), in: RoundedRectangle(cornerRadius: 7))
                        }

                        Text("LOCAL EDITOR • NO ROBLOX PROCESS CONNECTION")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.7)
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    .padding(12)
                    .background(Color(red: 0.13, green: 0.13, blue: 0.16))
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 14, y: 7)
                .padding(.horizontal, 14)
            } else {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isExecutorExpanded = true
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Text("Δ")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                            Text("OPEN MOBILEBLOX")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 45)
                        .background(Color(red: 0.16, green: 0.18, blue: 0.25), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.30, green: 0.48, blue: 0.82), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
        }
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

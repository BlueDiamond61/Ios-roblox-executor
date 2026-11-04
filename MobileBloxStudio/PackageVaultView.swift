import SwiftUI
import UniformTypeIdentifiers

struct PackageVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var packages: [URL] = []
    @State private var showingImporter = false
    @State private var packageToDelete: URL?
    @State private var showingDeleteConfirmation = false
    @State private var importMessage: String?

    private let accent = Color(red: 0.66, green: 0.43, blue: 1.0)
    private let panel = Color(red: 0.105, green: 0.085, blue: 0.16)
    private let background = Color(red: 0.055, green: 0.045, blue: 0.09)

    private var vaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PackageVault", isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 27))
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IPA PACKAGE VAULT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.3)
                                .foregroundStyle(accent)
                            Text("Keep app archives organized on this device.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(panel, in: RoundedRectangle(cornerRadius: 16))

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import IPA archive", systemImage: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }

                    if packages.isEmpty {
                        Spacer()
                        Image(systemName: "archivebox")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(accent.opacity(0.8))
                        Text("No IPA archives yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Imported .ipa files will appear here. This vault stores and shares archives; it does not install, modify, or execute them.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(packages, id: \.absoluteString) { url in
                                    packageRow(url)
                                }
                            }
                        }
                    }

                    if let importMessage {
                        Text(importMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Text("iOS controls app installation and developer trust. This vault cannot bypass certificate revocation or Apple's signing checks.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(panel, in: RoundedRectangle(cornerRadius: 13))
                }
                .padding(18)
            }
            .navigationTitle("Package Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                allowsMultipleSelection: true
            ) { result in
                importPackages(result)
            }
            .confirmationDialog(
                "Delete this archive from the vault?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let packageToDelete {
                        try? FileManager.default.removeItem(at: packageToDelete)
                        refreshPackages()
                    }
                }
            }
            .onAppear {
                try? FileManager.default.createDirectory(at: vaultFolder, withIntermediateDirectories: true)
                refreshPackages()
            }
        }
        .tint(accent)
    }

    private func packageRow(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 21))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(fileSize(url))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 4)

            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 38)
            }

            Menu {
                ShareLink(item: url) {
                    Label("Share archive", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    packageToDelete = url
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 30, height: 38)
            }
        }
        .padding(12)
        .background(panel, in: RoundedRectangle(cornerRadius: 15))
    }

    private func importPackages(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for source in urls {
                let access = source.startAccessingSecurityScopedResource()
                defer {
                    if access { source.stopAccessingSecurityScopedResource() }
                }

                guard source.pathExtension.lowercased() == "ipa" else { continue }
                let destination = uniqueDestination(for: source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: destination)
            }
            importMessage = "Import complete."
            refreshPackages()
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        var candidate = vaultFolder.appendingPathComponent(name)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = vaultFolder.appendingPathComponent("\(base)-\(index).ipa")
            index += 1
        }
        return candidate
    }

    private func refreshPackages() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: vaultFolder,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        packages = urls
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

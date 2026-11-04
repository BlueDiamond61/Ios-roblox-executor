import SwiftUI

struct EditorCodeSurface: View {
    @Binding var contents: String
    @State private var showingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(showingPreview ? "SYNTAX PREVIEW" : "EDIT SOURCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.66, green: 0.43, blue: 1.0))

                Spacer()

                Button {
                    showingPreview.toggle()
                } label: {
                    Label(showingPreview ? "Edit" : "Highlight", systemImage: showingPreview ? "pencil" : "paintpalette")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(.white.opacity(0.08))

            if showingPreview {
                ScrollView([.vertical, .horizontal]) {
                    Text(highlightedSource)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $contents)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color(red: 0.88, green: 0.85, blue: 0.94))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var highlightedSource: AttributedString {
        var result = AttributedString(contents)
        result.foregroundColor = Color(red: 0.88, green: 0.85, blue: 0.94)

        apply(pattern: #"\b(local|function|return|if|then|else|elseif|end|for|while|do|repeat|until|break|in|and|or|not|nil|true|false)\b"#,
              color: Color(red: 0.78, green: 0.59, blue: 1.0),
              to: &result)

        apply(pattern: #""[^"\n]*"|'[^'\n]*'"#,
              color: Color(red: 0.65, green: 0.83, blue: 0.63),
              to: &result)

        apply(pattern: #"\b\d+(\.\d+)?\b"#,
              color: Color(red: 0.96, green: 0.72, blue: 0.48),
              to: &result)

        apply(pattern: #"--[^\n]*"#,
              color: Color(red: 0.55, green: 0.62, blue: 0.58),
              to: &result)

        return result
    }

    private func apply(pattern: String, color: Color, to value: inout AttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let source = String(value.characters)
        let matches = regex.matches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )

        for match in matches {
            guard let range = Range(match.range, in: source),
                  let attributedRange = Range(range, in: value) else { continue }
            value[attributedRange].foregroundColor = color
        }
    }
}

struct InstallGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.66, green: 0.43, blue: 1.0)
    private let panel = Color(red: 0.105, green: 0.085, blue: 0.16)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.055, green: 0.045, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "iphone.and.arrow.down")
                                .font(.system(size: 30))
                                .foregroundStyle(accent)
                            Text("Install MobileBlox Studio")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("A local source editor companion. It does not connect to or execute code inside Roblox.")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.bottom, 4)

                        guideCard(
                            number: "01",
                            title: "Open the project in Xcode",
                            detail: "On a Mac, create a new iOS App project using SwiftUI, then add every Swift file from the MobileBloxStudio folder to the app target."
                        )

                        guideCard(
                            number: "02",
                            title: "Choose your signing team",
                            detail: "In Xcode, open Signing & Capabilities, select your Apple development team, and choose a unique bundle identifier."
                        )

                        guideCard(
                            number: "03",
                            title: "Run or distribute",
                            detail: "Connect your iPhone or select a simulator and press Run. For sharing with testers, use Apple's TestFlight workflow after archiving and uploading the app."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Using Windows?", systemImage: "desktopcomputer")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Windows can edit the Swift files, but Apple's Xcode toolchain is required to compile and sign an iOS app. This repository currently contains source code, not a ready-to-install signed IPA.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(panel, in: RoundedRectangle(cornerRadius: 16))

                        Text("No provisioning profiles, certificates, or device trust settings are bundled with this source project.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 2)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
        }
        .tint(accent)
    }

    private func guideCard(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: 16))
    }
}

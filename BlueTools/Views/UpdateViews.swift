import SwiftUI
import UIKit

struct UpdateSheet: View {
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss
    let info: ReleaseInfo

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(info.version)")
                            .font(.title2.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !info.notes.isEmpty {
                    Section("What's new") {
                        Text(markdown(info.notes))
                            .font(.callout)
                    }
                }

                Section {
                    InstallLinks(ipa: info.ipa)
                } header: {
                    Text("Install")
                } footer: {
                    Text("If you already added the source, just open SideStore or LiveContainer and refresh.")
                }

                Section {
                    Button("Skip this version", role: .destructive) {
                        updates.skip(info)
                    }
                }
            }
            .navigationTitle("Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private var subtitle: String {
        var text = "You have \(AppLinks.currentVersion)"
        if let published = info.published {
            text += ", released \(published.formatted(date: .abbreviated, time: .omitted))"
        }
        return text
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

struct InstallLinks: View {
    var ipa: URL?

    @State private var missingApp: String?
    @State private var copied = false

    var body: some View {
        Group {
            Button {
                open(AppLinks.sideStore, name: "SideStore")
            } label: {
                Label("Open in SideStore", systemImage: "arrow.up.forward.app")
            }

            Button {
                open(AppLinks.liveContainer, name: "LiveContainer")
            } label: {
                Label("Open in LiveContainer", systemImage: "arrow.up.forward.app")
            }

            if let ipa {
                Button {
                    ExternalApp.open(ipa)
                } label: {
                    Label("Download IPA", systemImage: "arrow.down.circle")
                }
            }

            Button {
                UIPasteboard.general.string = AppLinks.sourceString
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "Copied" : "Copy source URL", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
        }
        .alert(
            "\(missingApp ?? "App") not found",
            isPresented: Binding(get: { missingApp != nil }, set: { if !$0 { missingApp = nil } })
        ) {
            Button("Copy URL") {
                UIPasteboard.general.string = AppLinks.sourceString
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't open it. Copy the source URL and add it by hand.")
        }
    }

    private func open(_ url: URL, name: String) {
        ExternalApp.open(url) { ok in
            if !ok { missingApp = name }
        }
    }
}

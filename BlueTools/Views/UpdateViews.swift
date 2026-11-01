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
                        Text("Wersja \(info.version)")
                            .font(.title2.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !info.notes.isEmpty {
                    Section("Co nowego") {
                        Text(markdown(info.notes))
                            .font(.callout)
                    }
                }

                Section {
                    InstallLinks(ipa: info.ipa)
                } header: {
                    Text("Zainstaluj")
                } footer: {
                    Text("Jeśli masz już dodane źródło, wystarczy otworzyć SideStore albo LiveContainer i odświeżyć listę.")
                }

                Section {
                    Button("Pomiń tę wersję", role: .destructive) {
                        updates.skip(info)
                    }
                }
            }
            .navigationTitle("Aktualizacja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Później") { dismiss() }
                }
            }
        }
    }

    private var subtitle: String {
        var text = "Masz \(AppLinks.currentVersion)"
        if let published = info.published {
            text += ", nowa wyszła \(published.formatted(date: .abbreviated, time: .omitted))"
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
                Label("Otwórz w SideStore", systemImage: "arrow.up.forward.app")
            }

            Button {
                open(AppLinks.liveContainer, name: "LiveContainer")
            } label: {
                Label("Otwórz w LiveContainer", systemImage: "arrow.up.forward.app")
            }

            if let ipa {
                Button {
                    ExternalApp.open(ipa)
                } label: {
                    Label("Pobierz plik IPA", systemImage: "arrow.down.circle")
                }
            }

            Button {
                UIPasteboard.general.string = AppLinks.sourceString
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "Skopiowano" : "Kopiuj adres źródła", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
        }
        .alert(
            "Brak aplikacji \(missingApp ?? "")",
            isPresented: Binding(get: { missingApp != nil }, set: { if !$0 { missingApp = nil } })
        ) {
            Button("Kopiuj adres") {
                UIPasteboard.general.string = AppLinks.sourceString
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nie udało się jej otworzyć. Możesz skopiować adres źródła i dodać go ręcznie.")
        }
    }

    private func open(_ url: URL, name: String) {
        ExternalApp.open(url) { ok in
            if !ok { missingApp = name }
        }
    }
}

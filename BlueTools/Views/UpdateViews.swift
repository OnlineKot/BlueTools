import SwiftUI
import UIKit

struct UpdateSheet: View {
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss
    let info: ReleaseInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        AppIconBadge(size: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Jest nowa wersja")
                                .font(.title2.weight(.bold))
                            Text("\(AppLinks.currentVersion)  →  \(info.version)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if let published = info.published {
                                Text("Wydana \(published.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !info.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Co nowego")
                                .font(.headline)
                            Text(markdown(info.notes))
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Jak zaktualizować")
                            .font(.headline)
                        InstallButtons(ipa: info.ipa, page: info.page)
                    }

                    Button("Pomiń tę wersję") {
                        updates.skip(info)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Później") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

struct InstallButtons: View {
    var ipa: URL?
    var page: URL?

    @State private var missingApp: String?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 10) {
            InstallRow(
                title: "SideStore",
                subtitle: "Dodaj źródło, a aktualizacje przyjdą same",
                symbol: "plus.app.fill",
                tint: Color(red: 0.55, green: 0.33, blue: 0.95)
            ) {
                ExternalApp.open(AppLinks.sideStore) { ok in
                    if !ok { missingApp = "SideStore" }
                }
            }

            InstallRow(
                title: "LiveContainer",
                subtitle: "Dodaj źródło w LiveContainer",
                symbol: "shippingbox.fill",
                tint: Color(red: 0.12, green: 0.62, blue: 0.55)
            ) {
                ExternalApp.open(AppLinks.liveContainer) { ok in
                    if !ok { missingApp = "LiveContainer" }
                }
            }

            if let ipa {
                InstallRow(
                    title: "Pobierz IPA",
                    subtitle: "Do Sideloadly, TrollStore i innych",
                    symbol: "arrow.down.circle.fill",
                    tint: .accentColor
                ) {
                    ExternalApp.open(ipa)
                }
            }

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = AppLinks.sourceString
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "Skopiowano" : "Kopiuj adres źródła", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let page {
                    Button {
                        ExternalApp.open(page)
                    } label: {
                        Label("GitHub", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline)
        }
        .alert(
            "Nie znalazłem \(missingApp ?? "")",
            isPresented: Binding(get: { missingApp != nil }, set: { if !$0 { missingApp = nil } })
        ) {
            Button("Kopiuj adres źródła") {
                UIPasteboard.general.string = AppLinks.sourceString
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Wygląda na to, że ta aplikacja nie jest zainstalowana. Możesz skopiować adres źródła i wkleić go ręcznie.")
        }
    }
}

struct InstallRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AppIconBadge: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.15, green: 0.43, blue: 0.96), Color(red: 0.08, green: 0.2, blue: 0.59)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            Image(systemName: "dot.radiowaves.right")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

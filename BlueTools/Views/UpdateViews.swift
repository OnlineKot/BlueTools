import SwiftUI
import UIKit

struct UpdateSheet: View {
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.installer) private var savedInstaller = Installer.suggested.rawValue
    @State private var remember = true
    let info: ReleaseInfo

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(info.version) is out")
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
                    ForEach(InstallerList.ordered) { installer in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if remember { savedInstaller = installer.rawValue }
                            updates.install(info, with: installer)
                        } label: {
                            InstallerRow(installer: installer)
                        }
                    }
                    Toggle("Use this next time without asking", isOn: $remember)
                } header: {
                    Text("Install with")
                } footer: {
                    Text("BlueTools closes itself right after handing over, so the installer can replace it.")
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
            text += ". Released \(published.formatted(date: .abbreviated, time: .omitted))."
        }
        return text
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

struct InstallerRow: View {
    let installer: Installer

    var body: some View {
        HStack(spacing: 12) {
            InstallerIcon(installer: installer, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(installer.title)
                        .foregroundStyle(.primary)
                    if installer == Installer.suggested {
                        Text("You're here")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(installer.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct InstallerIcon: View {
    let installer: Installer
    var size: CGFloat = 30

    var body: some View {
        if let asset = installer.iconAsset {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        } else {
            Image(systemName: installer.symbol)
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }
    }
}

enum InstallerList {
    static var ordered: [Installer] {
        let suggested = Installer.suggested
        let base = Installer.choices
        return base.filter { $0 == suggested } + base.filter { $0 != suggested }
    }
}

struct InstallLinks: View {
    @EnvironmentObject private var updates: UpdateChecker
    @State private var copied = false

    var body: some View {
        Group {
            ForEach(Installer.choices) { installer in
                Button {
                    if let url = installer.url(ipa: AppLinks.latestIPA) {
                        ExternalApp.open(url) { ok in
                            if !ok { updates.missingInstaller = installer }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        InstallerIcon(installer: installer, size: 29)
                        Text(installer.title)
                            .foregroundStyle(.primary)
                    }
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
    }
}

struct UpdateCountdownBanner: View {
    @EnvironmentObject private var updates: UpdateChecker
    let countdown: UpdateChecker.Countdown

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(countdown.seconds) / 3)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdown.seconds)
                Text("\(countdown.seconds)")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Updating to \(countdown.info.version)")
                    .font(.subheadline.weight(.semibold))
                Text("Opening \(countdown.installer.title)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") {
                updates.countdown = nil
                updates.presented = countdown.info
            }
            .glassButton()
        }
        .padding(14)
        .glassCard(radius: 28, interactive: true)
        .padding(.horizontal, 16)
        .task(id: countdown.seconds) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            updates.tick()
        }
    }
}

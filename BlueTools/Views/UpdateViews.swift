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
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Version \(info.version) is out")
                                .font(.title.weight(.bold))
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)

                        if !info.notes.isEmpty {
                            CardSection(title: "What's new") {
                                Text(markdown(info.notes))
                                    .font(.callout)
                            }
                        }

                        CardSection(title: "Install with") {
                            InstallerList(ipa: info.ipa ?? AppLinks.latestIPA) { installer in
                                if remember { savedInstaller = installer.rawValue }
                                updates.install(info, with: installer)
                            }
                            Divider().padding(.vertical, 10)
                            Toggle("Use this next time without asking", isOn: $remember)
                                .font(.subheadline)
                        }

                        Text("BlueTools closes itself right after handing over, so the installer can replace it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)

                        Button("Skip this version") {
                            updates.skip(info)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }
            }
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

struct InstallerList: View {
    let ipa: URL
    let choose: (Installer) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(ordered) { installer in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    choose(installer)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: installer.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 38, height: 38)
                            .glassCircle(tint: Color.accentColor.opacity(0.12))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(installer.title)
                                    .font(.body.weight(.semibold))
                                if installer == Installer.suggested {
                                    Text("You're here")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            Text(installer.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .contentShape(Rectangle())
                    .glassCard(radius: 18, interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ordered: [Installer] {
        let suggested = Installer.suggested
        return Installer.choices.sorted { lhs, rhs in
            if lhs == suggested { return true }
            if rhs == suggested { return false }
            return Installer.choices.firstIndex(of: lhs)! < Installer.choices.firstIndex(of: rhs)!
        }
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
                    Label(installer.title, systemImage: installer.symbol)
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
        .glassCard(radius: 26)
        .padding(.horizontal, 16)
        .task(id: countdown.seconds) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            updates.tick()
        }
    }
}

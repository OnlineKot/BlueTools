import SwiftUI

struct SignalBars: View {
    let level: Int
    var dimmed: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < level ? barColor : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(5 + index * 3))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Sygnał \(level) na 4")
    }

    private var barColor: Color {
        if dimmed { return .secondary }
        switch level {
        case 4, 3: return .green
        case 2: return .orange
        default: return .red
        }
    }
}

struct Pill: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PulseDot: View {
    var active: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(active ? Color.green.opacity(0.35) : Color.clear)
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 1.6 : 0.8)
                .opacity(animate ? 0 : 1)
            Circle()
                .fill(active ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
        }
        .onAppear { restart() }
        .onChange(of: active) { _ in restart() }
    }

    private func restart() {
        animate = false
        guard active else { return }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            animate = true
        }
    }
}

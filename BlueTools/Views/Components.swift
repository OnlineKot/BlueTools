import SwiftUI

extension Color {
    static let mint1 = Color(red: 0.13, green: 0.78, blue: 0.62)
    static let ocean = Color(red: 0.08, green: 0.40, blue: 0.88)
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var value = Glass.regular
        if let tint { value = value.tint(tint) }
        if interactive { value = value.interactive() }
        return value
    }
}

struct GlassCapsule: ViewModifier {
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var value = Glass.regular
        if let tint { value = value.tint(tint) }
        if interactive { value = value.interactive() }
        return value
    }
}

struct GlassCircle: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: Circle())
        } else {
            content.background(.regularMaterial, in: Circle())
        }
    }
}

struct GlassButton: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    func glassCard(radius: CGFloat = 24, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassCard(radius: radius, tint: tint, interactive: interactive))
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassCapsule(tint: tint, interactive: interactive))
    }

    func glassCircle(tint: Color? = nil) -> some View {
        modifier(GlassCircle(tint: tint))
    }

    func glassButton(prominent: Bool = false) -> some View {
        modifier(GlassButton(prominent: prominent))
    }
}

struct SignalBars: View {
    let level: Int
    var dimmed: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < level ? barColor : Color.secondary.opacity(0.25))
                    .frame(width: 3.5, height: CGFloat(5 + index * 3))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Signal \(level) of 4")
    }

    private var barColor: Color {
        if dimmed { return .secondary }
        switch level {
        case 4, 3: return .mint1
        case 2: return .orange
        default: return .red
        }
    }
}

struct StatusLabel: View {
    let text: String
    var color: Color = .secondary
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(color)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .regular))
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
                    .glassButton(prominent: true)
                    .padding(.top, 6)
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
                .fill(active ? Color.mint1.opacity(0.4) : Color.clear)
                .frame(width: 12, height: 12)
                .scaleEffect(animate ? 1.8 : 0.8)
                .opacity(animate ? 0 : 1)
            Circle()
                .fill(active ? Color.mint1 : Color.secondary)
                .frame(width: 7, height: 7)
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

struct Toast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassCapsule()
            .padding(.horizontal, 24)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

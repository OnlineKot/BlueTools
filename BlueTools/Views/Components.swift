import SwiftUI

extension Color {
    static let mint1 = Color(red: 0.13, green: 0.83, blue: 0.66)
    static let ocean = Color(red: 0.08, green: 0.40, blue: 0.88)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(scheme == .dark ? Color(red: 0.02, green: 0.06, blue: 0.09) : Color(red: 0.93, green: 0.97, blue: 0.98))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    Circle()
                        .fill(Color.mint1.opacity(scheme == .dark ? 0.32 : 0.38))
                        .frame(width: width * 1.05, height: width * 1.05)
                        .blur(radius: 90)
                        .position(x: width * 0.12, y: proxy.size.height * 0.08)
                    Circle()
                        .fill(Color.ocean.opacity(scheme == .dark ? 0.38 : 0.30))
                        .frame(width: width * 1.15, height: width * 1.15)
                        .blur(radius: 100)
                        .position(x: width * 0.92, y: proxy.size.height * 0.82)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
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
            content.background(.ultraThinMaterial, in: Circle())
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

    func glassCircle(tint: Color? = nil) -> some View {
        modifier(GlassCircle(tint: tint))
    }

    func glassButton(prominent: Bool = false) -> some View {
        modifier(GlassButton(prominent: prominent))
    }
}

struct CardSection<Content: View>: View {
    let title: String
    var trailing: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                trailing
            }
            .padding(.horizontal, 6)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}

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

struct Pill: View {
    let text: String
    var color: Color = .accentColor
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(color)
        .glassCard(radius: 100, tint: color.opacity(0.15))
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
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 88, height: 88)
                .glassCircle()
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
                .fill(active ? Color.mint1.opacity(0.4) : Color.clear)
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 1.8 : 0.8)
                .opacity(animate ? 0 : 1)
            Circle()
                .fill(active ? Color.mint1 : Color.secondary)
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

struct Toast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassCard(radius: 100)
            .padding(.horizontal, 24)
    }
}

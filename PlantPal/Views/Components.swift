import SwiftUI

struct SkyBackground: View {
    var wilt: WiltLevel

    var body: some View {
        let top: Color = switch wilt {
        case .perky: Color(red: 0.86, green: 0.94, blue: 0.88)
        case .thirsty: Color(red: 0.96, green: 0.92, blue: 0.80)
        case .drooping: Color(red: 0.93, green: 0.86, blue: 0.76)
        case .crisis: Color(red: 0.86, green: 0.80, blue: 0.74)
        }
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [top, PlantTheme.cream], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(PlantTheme.sun.opacity(wilt == .crisis ? 0.18 : 0.75))
                .frame(width: 180, height: 180)
                .blur(radius: 6)
                .offset(x: 50, y: -10)
        }
    }
}

struct PalCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(PlantTheme.card)
                    .shadow(color: PlantTheme.soil.opacity(0.05), radius: 12, y: 6)
            )
    }
}

struct PalButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(filled ? Color.white : PlantTheme.soil)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? PlantTheme.leaf : Color.white.opacity(0.85))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PlantTheme.soil.opacity(filled ? 0 : 0.08), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct PalField: View {
    var title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PlantTheme.soilSoft)
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
        }
    }
}

struct WeekStrip: View {
    var dots: [DayDot]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dots) { dot in
                VStack(spacing: 6) {
                    Text(dot.weekday.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PlantTheme.soilSoft)
                    Circle()
                        .fill(fill(dot))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(PlantTheme.soil.opacity(0.12), lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label(dot))
            }
        }
    }

    private func fill(_ dot: DayDot) -> Color {
        switch dot.state {
        case .beforePlant: return Color.white.opacity(0.3)
        case .missed: return PlantTheme.terracotta.opacity(0.85)
        case .thriving: return PlantTheme.leaf
        case .today(let watered, let needed):
            if needed > 0 && watered >= needed { return PlantTheme.leaf }
            if watered > 0 { return PlantTheme.sun }
            return Color.white
        }
    }

    private func label(_ dot: DayDot) -> String {
        switch dot.state {
        case .beforePlant: return "\(dot.weekday), before the plant"
        case .missed: return "\(dot.weekday), missed"
        case .thriving: return "\(dot.weekday), thriving"
        case .today(let watered, let needed): return "Today, \(watered) of \(needed) watered"
        }
    }
}

struct ScreenHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PlantTheme.soil)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PlantTheme.soilSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

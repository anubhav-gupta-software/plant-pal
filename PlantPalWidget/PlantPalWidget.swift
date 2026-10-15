import SwiftUI
import WidgetKit
import PlantPalKit

struct PlantEntry: TimelineEntry {
    var date: Date
    var document: PlantDocument?
    var profile: DeviceProfile?
    var showsSample: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PlantEntry {
        PlantEntry(date: .now, document: SamplePlant.preview(), profile: nil, showsSample: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlantEntry) -> Void) {
        let store = SharedPlantStore()
        let document = store.loadDocument()
        if document == nil, context.isPreview {
            completion(PlantEntry(date: .now, document: SamplePlant.preview(), profile: store.loadProfile(), showsSample: true))
        } else {
            completion(PlantEntry(date: .now, document: document, profile: store.loadProfile(), showsSample: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlantEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private static func loadEntry() async -> PlantEntry {
        let store = SharedPlantStore()
        var document = store.loadDocument()
        let profile = store.loadProfile()
        if profile?.syncMode == .cloudKit, let current = document {
            if let remote = try? await CloudKitPlantSync().fetch(inviteCode: current.inviteCode) {
                let merged = PlantMerge.merge(local: current, remote: remote)
                if !PlantMerge.isSameContent(merged, current) || !PlantMerge.isSameContent(merged, remote) {
                    if !PlantMerge.isSameContent(merged, remote),
                       let uploaded = try? await CloudKitPlantSync().upload(merged) {
                        store.saveDocument(uploaded)
                        document = uploaded
                    } else {
                        store.saveDocument(merged)
                        document = merged
                    }
                }
            }
        }
        return PlantEntry(date: .now, document: document, profile: profile, showsSample: false)
    }
}

struct PlantPalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plantpal.home", provider: Provider()) { entry in
            PlantWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Plant Pal")
        .description("See your shared plant and give it today's sip.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct PlantWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PlantEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                backdrop
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            medium
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            small
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetBackground()
        default:
            LinearGradient(
                colors: [Color(red: 0.90, green: 0.95, blue: 0.90), Color(red: 0.98, green: 0.96, blue: 0.93)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var small: some View {
        VStack(spacing: 4) {
            if let document = entry.document, let derived = PlantEngine.derive(document, now: entry.date) {
                PlantBadge(species: document.species, pot: document.pot, stage: derived.stage, wilt: derived.appearanceWilt)
                    .frame(height: 78)
                Text(document.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PlantTheme.soil)
                Text(PlantCopy.widgetLine(document: document, derived: derived, myPartnerID: entry.profile?.myPartnerID))
                    .font(.caption2)
                    .foregroundStyle(PlantTheme.soilSoft)
                waterControl(document: document, derived: derived)
            } else {
                empty(compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            if let document = entry.document, let derived = PlantEngine.derive(document, now: entry.date) {
                PlantBadge(species: document.species, pot: document.pot, stage: derived.stage, wilt: derived.appearanceWilt)
                    .frame(maxWidth: 120, maxHeight: 140)
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PlantTheme.soil)
                    Text(derived.stage.title)
                        .font(.caption)
                        .foregroundStyle(PlantTheme.soilSoft)
                    ForEach(document.partners) { partner in
                        HStack(spacing: 6) {
                            Image(systemName: derived.wateredToday.contains(partner.id) ? "drop.fill" : "drop")
                                .foregroundStyle(PlantTheme.leafDeep)
                            Text(partner.name)
                                .font(.caption)
                                .foregroundStyle(PlantTheme.soil)
                        }
                    }
                    waterControl(document: document, derived: derived)
                }
                Spacer(minLength: 0)
            } else {
                empty(compact: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var circular: some View {
        Group {
            if entry.document != nil, SharedPlantStore().appGroupAvailable, !entry.showsSample {
                Button(intent: WaterPlantIntent()) {
                    SproutMark()
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: URL(string: "plantpal://water")!) {
                    SproutMark()
                }
            }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            SproutMark()
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.document?.name ?? "Plant Pal")
                    .font(.headline)
                    .widgetAccentable()
                Text(statusLine)
                    .font(.caption2)
                if entry.document != nil, !entry.showsSample, alreadyWatered == false {
                    waterLink
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var inline: some View {
        Text(inlineText)
    }

    private var statusLine: String {
        guard let document = entry.document else { return "Open to plant" }
        let derived = PlantEngine.derive(document, now: entry.date)
        return PlantCopy.widgetLine(document: document, derived: derived, myPartnerID: entry.profile?.myPartnerID)
    }

    private var inlineText: String {
        guard let document = entry.document else { return "Plant Pal" }
        let derived = PlantEngine.derive(document, now: entry.date)
        return "\(document.name) · \(derived.currentStreak)d · \(statusLine)"
    }

    private var alreadyWatered: Bool {
        guard let document = entry.document, let id = entry.profile?.myPartnerID else { return false }
        let derived = PlantEngine.derive(document, now: entry.date)
        return derived.wateredToday.contains(id)
    }

    @ViewBuilder
    private func waterControl(document: PlantDocument, derived: DerivedPlant) -> some View {
        if entry.showsSample {
            Text("Preview")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PlantTheme.soilSoft)
        } else if let id = entry.profile?.myPartnerID, derived.wateredToday.contains(id) {
            Label("Sipped", systemImage: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PlantTheme.leafDeep)
        } else if SharedPlantStore().appGroupAvailable {
            Button(intent: WaterPlantIntent()) {
                Label("Water", systemImage: "drop.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(PlantTheme.leaf))
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "plantpal://water")!) {
                Label("Water", systemImage: "drop.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(PlantTheme.leaf))
            }
        }
    }

    private var waterLink: some View {
        Group {
            if SharedPlantStore().appGroupAvailable {
                Button(intent: WaterPlantIntent()) {
                    Text("Water")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: URL(string: "plantpal://water")!) {
                    Text("Water")
                        .font(.caption2.weight(.bold))
                }
            }
        }
    }

    private func empty(compact: Bool) -> some View {
        VStack(spacing: 6) {
            PlantBadge(species: .sproutling, pot: .terracotta, stage: .seed, wilt: .perky)
                .frame(height: compact ? 70 : 90)
            Text("Open Plant Pal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PlantTheme.soil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "plantpal://home"))
    }
}

private struct SproutMark: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(.brown)
                .frame(width: 22, height: 12)
                .offset(y: 12)
                .widgetAccentable()
            Capsule()
                .fill(.green)
                .frame(width: 4, height: 18)
                .widgetAccentable()
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
                .offset(x: -7, y: -2)
                .widgetAccentable()
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
                .offset(x: 7, y: -6)
                .widgetAccentable()
        }
        .accessibilityLabel("Plant Pal")
    }
}

@main
struct PlantPalWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlantPalWidget()
    }
}

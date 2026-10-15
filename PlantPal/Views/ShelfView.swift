import SwiftUI

struct ShelfView: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let document = model.document, let derived = model.derived {
                    ScreenHeader(title: "Shelf", subtitle: "Pots and species unlock on thriving days, then you can dress \(document.name) up.")
                    sectionTitle("Pots")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PotStyle.allCases) { pot in
                            shelfCard(
                                title: pot.displayName,
                                blurb: pot.blurb,
                                unlocked: derived.unlockedPots.contains(pot),
                                days: pot.unlockThrivingDays,
                                thriving: derived.totalThrivingDays,
                                selected: document.pot == pot
                            ) {
                                PlantBadge(species: document.species, pot: pot, stage: .bloom, wilt: .perky)
                            } onTap: {
                                model.equip(pot: pot)
                            }
                        }
                    }
                    sectionTitle("Species")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PlantSpecies.allCases) { species in
                            shelfCard(
                                title: species.displayName,
                                blurb: species.blurb,
                                unlocked: derived.unlockedSpecies.contains(species),
                                days: species.unlockThrivingDays,
                                thriving: derived.totalThrivingDays,
                                selected: document.species == species
                            ) {
                                PlantBadge(species: species, pot: document.pot, stage: .bloom, wilt: .perky)
                            } onTap: {
                                model.equip(species: species)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PlantTheme.cream.ignoresSafeArea())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(PlantTheme.soil)
    }

    private func shelfCard<Preview: View>(
        title: String,
        blurb: String,
        unlocked: Bool,
        days: Int,
        thriving: Int,
        selected: Bool,
        @ViewBuilder preview: () -> Preview,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                preview()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.55)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                Text(unlocked ? (days == 0 ? "From the start" : "Unlocked") : "After \(days) thriving days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(unlocked ? PlantTheme.leafDeep : PlantTheme.terracotta)
                Text(blurb)
                    .font(.caption)
                    .foregroundStyle(PlantTheme.soilSoft)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if !unlocked {
                    Text("\(max(0, days - thriving)) to go")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PlantTheme.soilSoft)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(selected ? PlantTheme.leaf : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(unlocked ? "unlocked" : "locked")")
    }
}

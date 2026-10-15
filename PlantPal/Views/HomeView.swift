import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let wilt = model.derived?.appearanceWilt ?? .perky
        ScrollView {
            VStack(spacing: 18) {
                if let document = model.document, let derived = model.derived {
                    header(document: document, derived: derived)
                    PlantScene(
                        species: document.species,
                        pot: document.pot,
                        stage: derived.stage,
                        wilt: derived.appearanceWilt,
                        isWatering: model.isWatering
                    )
                    .frame(height: 320)
                    .accessibilityLabel(PlantCopy.headline(document: document, derived: derived))
                    PalCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(PlantCopy.headline(document: document, derived: derived))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(PlantTheme.soil)
                            Text(PlantCopy.detail(document: document, derived: derived))
                                .font(.subheadline)
                                .foregroundStyle(PlantTheme.soilSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    PalCard {
                        WeekStrip(dots: PlantEngine.recentDots(document: document))
                    }
                    VStack(spacing: 12) {
                        ForEach(document.partners) { partner in
                            partnerCard(partner, document: document, derived: derived)
                        }
                    }
                    if document.partners.count < 2 {
                        Button("Add a practice pal") {
                            model.addPracticePal(name: "Practice Pal")
                        }
                        .buttonStyle(PalButtonStyle(filled: false))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SkyBackground(wilt: wilt).ignoresSafeArea())
    }

    private func header(document: PlantDocument, derived: DerivedPlant) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                Text("\(derived.stage.title) · \(derived.wilt.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PlantTheme.soilSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(derived.currentStreak)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.leafDeep)
                Text(derived.currentStreak == 1 ? "day" : "days")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PlantTheme.soilSoft)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(derived.currentStreak) day streak")
        }
    }

    private func partnerCard(_ partner: Partner, document: PlantDocument, derived: DerivedPlant) -> some View {
        let watered = derived.wateredToday.contains(partner.id)
        let mine = partner.id == model.profile.myPartnerID
        return PalCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(watered ? PlantTheme.leaf.opacity(0.2) : PlantTheme.blush.opacity(0.7))
                    Text(String(partner.name.prefix(1)).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PlantTheme.soil)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.name)
                        .font(.headline)
                        .foregroundStyle(PlantTheme.soil)
                    Text(watered ? "Sipped today" : "Still to water")
                        .font(.subheadline)
                        .foregroundStyle(watered ? PlantTheme.leafDeep : PlantTheme.soilSoft)
                    if partner.isStandIn {
                        Text("Practice pal")
                            .font(.caption)
                            .foregroundStyle(PlantTheme.soilSoft)
                    }
                }
                Spacer()
                if watered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PlantTheme.leaf)
                        .accessibilityLabel("Watered")
                } else if model.canWater(partner.id) {
                    Button(mine ? "I watered" : "Water") {
                        model.water(partner.id)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(PlantTheme.leaf))
                    .accessibilityLabel(mine ? "I watered" : "Water as \(partner.name)")
                }
            }
        }
    }
}

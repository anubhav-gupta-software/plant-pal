import SwiftUI

struct JourneyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let document = model.document, let derived = model.derived {
                    ScreenHeader(title: "Journey", subtitle: "\(document.name) has been with you \(derived.daysTogether) days.")
                    HStack(spacing: 10) {
                        stat("Thriving", value: "\(derived.totalThrivingDays)")
                        stat("Streak", value: "\(derived.currentStreak)")
                        stat("Best", value: "\(derived.longestStreak)")
                    }
                    if let next = derived.nextUnlock {
                        PalCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Up next")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PlantTheme.leafDeep)
                                Text(next.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(PlantTheme.soil)
                                Text(next.daysRemaining == 0 ? "Ready now." : "\(next.daysRemaining) thriving \(next.daysRemaining == 1 ? "day" : "days") to go.")
                                    .font(.subheadline)
                                    .foregroundStyle(PlantTheme.soilSoft)
                            }
                        }
                    }
                    PalCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(GrowthStage.allCases) { stage in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(derived.stage.rawValue >= stage.rawValue ? PlantTheme.leaf : PlantTheme.creamDeep)
                                        .frame(width: 14, height: 14)
                                        .padding(.top, 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stage.title)
                                            .font(.headline)
                                            .foregroundStyle(PlantTheme.soil)
                                        Text(stage.blurb)
                                            .font(.subheadline)
                                            .foregroundStyle(PlantTheme.soilSoft)
                                    }
                                    Spacer()
                                    Text(stage.daysRequired == 0 ? "Start" : "Day \(stage.daysRequired)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PlantTheme.soilSoft)
                                }
                            }
                        }
                    }
                    PalCard {
                        Text("A thriving day means every partner watered. Those days grow the plant and heal one step of wilt. If a day ends short, the streak resets and the leaves droop. Wilt stops at a crisis, and while you're waiting for a pal your own sip still counts.")
                            .font(.subheadline)
                            .foregroundStyle(PlantTheme.soilSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
        }
        .background(PlantTheme.cream.ignoresSafeArea())
    }

    private func stat(_ title: String, value: String) -> some View {
        PalCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlantTheme.soilSoft)
            }
        }
    }
}

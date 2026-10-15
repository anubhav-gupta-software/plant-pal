import AppIntents
import PlantPalKit

struct PlantPalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WaterPlantIntent(),
            phrases: ["Water my plant with \(.applicationName)"],
            shortTitle: "Water",
            systemImageName: "drop.fill"
        )
    }
}

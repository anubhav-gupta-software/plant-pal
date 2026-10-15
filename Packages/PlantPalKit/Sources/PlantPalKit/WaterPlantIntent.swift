import AppIntents
import Foundation
import WidgetKit

public struct WaterPlantIntent: AppIntent {
    public static var title: LocalizedStringResource = "Water your plant"
    public static var description = IntentDescription("Mark today's sip for you.")
    public static var openAppWhenRun = false
    public static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = SharedPlantStore()
        guard store.appGroupAvailable || store.loadDocument() != nil else {
            return .result(dialog: "Open Plant Pal and start a plant first.")
        }
        guard var document = store.loadDocument() else {
            return .result(dialog: "Open Plant Pal and start a plant first.")
        }
        guard let myID = store.loadProfile()?.myPartnerID,
              document.partners.contains(where: { $0.id == myID }) else {
            return .result(dialog: "Open Plant Pal to choose who is watering.")
        }
        let result = PlantEngine.water(&document, partnerID: myID)
        let name = document.name
        if result == .watered {
            store.saveDocument(document)
            if store.loadProfile()?.syncMode == .cloudKit {
                if let saved = try? await CloudKitPlantSync().upload(document) {
                    store.saveDocument(saved)
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "You watered \(name).")
        }
        return .result(dialog: "You already watered \(name) today.")
    }
}

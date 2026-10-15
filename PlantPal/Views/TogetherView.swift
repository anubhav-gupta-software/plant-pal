import SwiftUI
import UIKit

struct TogetherView: View {
    @Environment(AppModel.self) private var model
    @State private var plantName = ""
    @State private var partnerNames: [UUID: String] = [:]
    @State private var reminderDate = Date()
    @State private var showPaste = false
    @State private var showReset = false
    @State private var practiceName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Us",
                    subtitle: "Days follow the timezone of whoever started the plant, so today means the same thing on both phones."
                )
                if let document = model.document {
                    namesCard(document)
                    codeCard(document)
                    reminderCard
                    syncCard
                    widgetCard
                    Button("Start over", role: .destructive) { showReset = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .background(PlantTheme.cream.ignoresSafeArea())
        .onAppear { loadDrafts() }
        .onChange(of: model.document?.partners.map(\.id)) { _, _ in
            loadDrafts()
        }
        .sheet(isPresented: $showPaste) {
            PastePostcardSheet()
                .environment(model)
        }
        .confirmationDialog("Let this plant go?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { model.resetGarden() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the plant on this phone. A copy in iCloud stays until you delete that too.")
        }
    }

    private func namesCard(_ document: PlantDocument) -> some View {
        PalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Names")
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                PalField(title: "Plant", text: $plantName)
                Button("Save plant name") { model.renamePlant(plantName) }
                    .buttonStyle(PalButtonStyle(filled: false))
                ForEach(document.partners) { partner in
                    PalField(title: partner.id == model.profile.myPartnerID ? "You" : "Pal", text: nameBinding(partner))
                    Button("Save \(partner.name)") {
                        model.renamePartner(id: partner.id, name: partnerNames[partner.id] ?? partner.name)
                    }
                    .buttonStyle(PalButtonStyle(filled: false))
                }
                if document.partners.count < 2 {
                    PalField(title: "Practice pal", text: $practiceName)
                    Button("Add a practice pal") {
                        model.addPracticePal(name: practiceName.isEmpty ? "Practice Pal" : practiceName)
                        practiceName = ""
                    }
                    .buttonStyle(PalButtonStyle())
                    Text("A practice pal waters from this phone so you can see a thriving day before a real friend joins. They step aside when someone joins for real.")
                        .font(.footnote)
                        .foregroundStyle(PlantTheme.soilSoft)
                }
            }
        }
    }

    private func codeCard(_ document: PlantDocument) -> some View {
        PalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Invite")
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                Text(document.inviteCode)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(PlantTheme.leafDeep)
                Text(model.profile.syncMode == .cloudKit
                     ? "Your pal enters this code after they turn on iCloud in Plant Pal."
                     : "This code connects over iCloud. Until then, send a postcard and your pal pastes it.")
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.soilSoft)
                Button("Copy code") {
                    UIPasteboard.general.string = document.inviteCode
                }
                .buttonStyle(PalButtonStyle(filled: false))
                ShareLink(item: model.postcardText) {
                    Text("Send a postcard")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(PlantTheme.leaf))
                }
                Button("Paste a postcard") { showPaste = true }
                    .buttonStyle(PalButtonStyle(filled: false))
            }
        }
    }

    private var reminderCard: some View {
        PalCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reminder")
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                Text("A local notification, on this phone only. It doesn't need push, so a free Apple ID can use it.")
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.soilSoft)
                Toggle("Daily sip reminder", isOn: Binding(
                    get: { model.profile.remindersEnabled },
                    set: { enabled in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
                        Task {
                            await model.setReminders(enabled: enabled, hour: parts.hour ?? 19, minute: parts.minute ?? 0)
                        }
                    }
                ))
                .tint(PlantTheme.leaf)
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { reminderDate },
                        set: { newValue in
                            reminderDate = newValue
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            Task { await model.updateReminderTime(hour: parts.hour ?? 19, minute: parts.minute ?? 0) }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                if model.reminderDenied {
                    Text("Notifications are off for Plant Pal. You can allow them in Settings.")
                        .font(.footnote)
                        .foregroundStyle(PlantTheme.terracotta)
                }
            }
        }
    }

    private var syncCard: some View {
        PalCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sync")
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                Picker("Sync", selection: Binding(
                    get: { model.profile.syncMode },
                    set: { mode in Task { await model.setSyncMode(mode) } }
                )) {
                    Text("This phone").tag(SyncMode.local)
                    Text("iCloud").tag(SyncMode.cloudKit)
                }
                .pickerStyle(.segmented)
                Text("iCloud uses CloudKit container \(SyncConfig.cloudKitContainerIdentifier). Turning it on needs the iCloud capability, which a free personal team can't sign. Postcards still merge both sips.")
                    .font(.footnote)
                    .foregroundStyle(PlantTheme.soilSoft)
                Button(model.isSyncing ? "Syncing…" : "Sync now") {
                    Task { await model.refreshFromCloud(userInitiated: true) }
                }
                .buttonStyle(PalButtonStyle(filled: false))
                .disabled(model.profile.syncMode != .cloudKit || model.isSyncing)
                if let message = model.syncMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PlantTheme.soilSoft)
                }
            }
        }
    }

    private var widgetCard: some View {
        PalCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Widgets")
                    .font(.headline)
                    .foregroundStyle(PlantTheme.soil)
                if model.appGroupAvailable {
                    Text("Home Screen and Lock Screen widgets can see \(model.document?.name ?? "the plant") and the water button writes straight through.")
                        .font(.subheadline)
                        .foregroundStyle(PlantTheme.soilSoft)
                } else {
                    Text("The widget is installed with the app. Live state and the water button need the App Group \(SyncConfig.appGroupIdentifier), and a free personal team can't sign that. Until then, the widget opens Plant Pal so you can water here.")
                        .font(.subheadline)
                        .foregroundStyle(PlantTheme.soilSoft)
                }
            }
        }
    }

    private func loadDrafts() {
        plantName = model.document?.name ?? ""
        var names: [UUID: String] = [:]
        for partner in model.document?.partners ?? [] {
            names[partner.id] = partner.name
        }
        partnerNames = names
        var components = DateComponents()
        components.hour = model.profile.reminderHour
        components.minute = model.profile.reminderMinute
        reminderDate = Calendar.current.date(from: components) ?? reminderDate
    }

    private func nameBinding(_ partner: Partner) -> Binding<String> {
        Binding(
            get: { partnerNames[partner.id] ?? partner.name },
            set: { partnerNames[partner.id] = $0 }
        )
    }
}

struct PastePostcardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var choice: PlantDocument?
    @State private var replacing: PlantDocument?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Paste the whole postcard, including the PLANTPAL1 bit.")
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.soilSoft)
                TextEditor(text: $text)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(RoundedRectangle(cornerRadius: 16).fill(PlantTheme.creamDeep))
                    .frame(minHeight: 160)
                Button("Paste from clipboard") {
                    text = UIPasteboard.general.string ?? text
                }
                .buttonStyle(PalButtonStyle(filled: false))
                Button("Merge") { merge() }
                    .buttonStyle(PalButtonStyle())
                if let choice {
                    Text("Which one are you?")
                        .font(.headline)
                    ForEach(choice.partners) { partner in
                        Button(partner.name) {
                            model.choosePartner(partner.id, on: choice)
                            dismiss()
                        }
                        .buttonStyle(PalButtonStyle(filled: false))
                    }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog("Replace the plant on this phone?", isPresented: Binding(
                get: { replacing != nil },
                set: { if !$0 { replacing = nil } }
            )) {
                Button("Replace", role: .destructive) {
                    if let replacing {
                        _ = model.replaceWithPostcard(replacing, myName: model.profile.displayName)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { replacing = nil }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func merge() {
        let name = model.profile.displayName.isEmpty ? "Pal" : model.profile.displayName
        switch model.importPostcard(text, myName: name) {
        case .merged, .joined:
            dismiss()
        case .needChoice(let plant):
            choice = plant
        case .needReplace(let plant):
            replacing = plant
        case .failed:
            break
        }
    }
}

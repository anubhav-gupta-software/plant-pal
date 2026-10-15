import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .welcome
    @State private var myName = ""
    @State private var plantName = ""
    @State private var palName = ""
    @State private var code = ""
    @State private var postcard = ""
    @State private var choice: PlantDocument?
    @State private var replacing: PlantDocument?
    @State private var busy = false
    @State private var cloudNote: String?

    private let suggestions = ["Pip", "Momo", "Bean", "Nori"]

    var body: some View {
        ZStack {
            SkyBackground(wilt: .perky).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        PlantScene(
                            species: .sproutling,
                            pot: .terracotta,
                            stage: step == .welcome ? .seed : .sprout,
                            wilt: .perky,
                            isWatering: false
                        )
                        .frame(height: step == .welcome ? 280 : 180)
                        .padding(.top, 12)
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .animation(.spring(duration: 0.45), value: step)
        .onAppear {
            if model.document != nil, !model.profile.onboardingComplete {
                step = .invite
            }
        }
        .confirmationDialog(
            "Replace the plant on this phone?",
            isPresented: Binding(
                get: { replacing != nil },
                set: { if !$0 { replacing = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                if let replacing {
                    _ = model.replaceWithPostcard(replacing, myName: myName)
                }
                replacing = nil
            }
            Button("Cancel", role: .cancel) { replacing = nil }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 12) {
                Text("Grow one plant, together")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                    .multilineTextAlignment(.center)
                Text("You and one person each water it once a day. It sprouts when you both show up, and droops a little when a day slips by.")
                    .font(.body)
                    .foregroundStyle(PlantTheme.soilSoft)
                    .multilineTextAlignment(.center)
                Button("Let's plant") { step = .names }
                    .buttonStyle(PalButtonStyle())
                    .padding(.top, 8)
            }
        case .names:
            VStack(alignment: .leading, spacing: 14) {
                Text("Who's here?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                PalField(title: "Your name", text: $myName)
                PalField(title: "Plant name", text: $plantName)
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { name in
                        Button(name) { plantName = name }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.8)))
                            .foregroundStyle(PlantTheme.soil)
                    }
                }
                Button("Continue") { step = .how }
                    .buttonStyle(PalButtonStyle())
                    .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 4)
            }
        case .how:
            VStack(alignment: .leading, spacing: 12) {
                Text("How will you water?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                choiceCard(
                    title: "Same phone",
                    detail: "You pass it back and forth. Both of you tap your own sip.",
                    symbol: "iphone"
                ) { step = .pal }
                choiceCard(
                    title: "Two phones",
                    detail: "Share a code over iCloud, or a postcard if you're staying on a free Apple ID.",
                    symbol: "person.2"
                ) { step = .inviteSetup }
                Button("I have a code or a postcard") { step = .join }
                    .buttonStyle(PalButtonStyle(filled: false))
            }
        case .pal:
            VStack(alignment: .leading, spacing: 14) {
                Text("Your pal's name")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                Text("They'll get their own button on this phone.")
                    .foregroundStyle(PlantTheme.soilSoft)
                PalField(title: "Pal's name", text: $palName)
                Button("Plant it") {
                    model.startPassAndPlay(myName: myName, plantName: plantName, palName: palName)
                }
                .buttonStyle(PalButtonStyle())
                .disabled(palName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        case .inviteSetup:
            VStack(alignment: .leading, spacing: 12) {
                Text("Start the plant")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PlantTheme.soil)
                Text("A postcard works today. An invite code meets your pal in iCloud, which needs the paid developer program.")
                    .foregroundStyle(PlantTheme.soilSoft)
                Button(busy ? "Connecting…" : "Try iCloud, then show my code") {
                    Task {
                        busy = true
                        let ok = await model.startLinkedWithCloud(myName: myName, plantName: plantName)
                        cloudNote = ok ? "iCloud is on. Your pal can join with the code." : model.syncMessage
                        busy = false
                        step = .invite
                    }
                }
                .buttonStyle(PalButtonStyle())
                .disabled(busy)
                Button("Skip iCloud and use a postcard") {
                    model.startLinked(myName: myName, plantName: plantName)
                    cloudNote = "Send the postcard. Your pal pastes it to join."
                    step = .invite
                }
                .buttonStyle(PalButtonStyle(filled: false))
            }
        case .invite:
            inviteBody
        case .join:
            joinBody
        }
    }

    private var inviteBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.document?.name ?? "Your plant")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PlantTheme.soil)
            if let note = cloudNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.soilSoft)
            }
            Text(model.document?.inviteCode ?? "")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(PlantTheme.leafDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            Button("Copy code") {
                UIPasteboard.general.string = model.document?.inviteCode ?? ""
            }
            .buttonStyle(PalButtonStyle(filled: false))
            ShareLink(item: model.postcardText) {
                Text("Send a postcard")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PlantTheme.soil)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
            }
            Button("Go to our plant") { model.finishOnboarding() }
                .buttonStyle(PalButtonStyle())
                .disabled(model.document == nil)
            Text("You can water while you wait. Until someone joins, your own sip keeps the day thriving.")
                .font(.footnote)
                .foregroundStyle(PlantTheme.soilSoft)
        }
    }

    private var joinBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Join your pal")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PlantTheme.soil)
            PalField(title: "Invite code", text: $code)
            Button(busy ? "Looking…" : "Join with iCloud") {
                Task {
                    busy = true
                    _ = await model.joinWithCode(code, myName: myName.isEmpty ? "Pal" : myName)
                    busy = false
                }
            }
            .buttonStyle(PalButtonStyle())
            .disabled(busy)
            if let message = model.syncMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PlantTheme.soilSoft)
            }
            Text("Or paste a postcard")
                .font(.headline)
                .padding(.top, 8)
            TextEditor(text: $postcard)
                .frame(minHeight: 90)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.9)))
            Button("Paste from clipboard") {
                postcard = UIPasteboard.general.string ?? postcard
            }
            .buttonStyle(PalButtonStyle(filled: false))
            Button("Open postcard") { openPostcard() }
                .buttonStyle(PalButtonStyle())
            if let choice {
                Text("Which one are you?")
                    .font(.headline)
                ForEach(choice.partners) { partner in
                    Button(partner.name) {
                        model.choosePartner(partner.id, on: choice)
                    }
                    .buttonStyle(PalButtonStyle(filled: false))
                }
            }
            Button("Back") { step = .how }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PlantTheme.soilSoft)
                .frame(maxWidth: .infinity)
        }
    }

    private func choiceCard(title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(PlantTheme.leafDeep)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PlantTheme.soil)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(PlantTheme.soilSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.82)))
        }
        .buttonStyle(.plain)
    }

    private func openPostcard() {
        switch model.importPostcard(postcard, myName: myName.isEmpty ? "Pal" : myName) {
        case .needChoice(let plant):
            choice = plant
        case .needReplace(let plant):
            replacing = plant
        default:
            choice = nil
        }
    }
}

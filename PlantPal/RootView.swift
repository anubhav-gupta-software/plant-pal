import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, journey, shelf, us

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .journey: return "Journey"
        case .shelf: return "Shelf"
        case .us: return "Us"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "leaf.fill"
        case .journey: return "map.fill"
        case .shelf: return "archivebox.fill"
        case .us: return "person.2.fill"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.profile.onboardingComplete, model.document != nil {
                MainShell()
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .top) {
            if let banner = model.banner {
                Text(banner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(PlantTheme.soil))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: model.banner)
        .sensoryFeedback(.success, trigger: model.waterTicks)
        .onOpenURL { model.handle($0) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await model.refreshFromCloud(userInitiated: false)
                await model.ensureReminder()
            }
        }
    }
}

struct MainShell: View {
    @State private var tab: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: HomeView()
                case .journey: JourneyView()
                case .shelf: ShelfView()
                case .us: TogetherView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PalTabBar(tab: $tab)
        }
        .background(PlantTheme.cream.ignoresSafeArea())
    }
}

struct PalTabBar: View {
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(tab == item ? PlantTheme.leafDeep : PlantTheme.soilSoft.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}

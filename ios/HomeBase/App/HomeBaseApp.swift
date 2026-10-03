import SwiftUI
import SwiftData

@main
struct HomeBaseApp: App {
    @State private var health = HealthStore.shared

    init() {
        // Observers must be registered at every launch so Apple Health can wake the app in the background.
        HealthStore.shared.startIfAuthorized()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(health)
                .modelContainer(for: LiftSession.self)
                .preferredColorScheme(.dark)
                .tint(.hbAccent)
        }
    }
}

struct RootView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "waveform.path.ecg") }
            TrainView()
                .tabItem { Label("Train", systemImage: "dumbbell") }
            ComingNextView(title: "Money", detail: "Budgets and CIBC transactions move here after the Plaid server is set up.", icon: "creditcard")
                .tabItem { Label("Money", systemImage: "creditcard") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "person.crop.circle") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await health.refresh() } }
        }
    }
}

struct ComingNextView: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 40)).foregroundStyle(Color.hbAccent)
                Text(detail).multilineTextAlignment(.center).foregroundStyle(Color.hbMuted)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.hbBackground)
            .navigationTitle(title)
        }
    }
}

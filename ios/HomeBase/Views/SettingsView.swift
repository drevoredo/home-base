import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ConnectionsView() } label: {
                        Label("Connections", systemImage: "link")
                    }
                }
                Section("Daily targets") {
                    TargetsForm()
                }
                Section {
                    Text("Home Base reads from and writes to Apple Health on this iPhone. Your wife connects her own Health on her own iPhone, and cycle tracking stays private to each of you.")
                        .font(.footnote).foregroundStyle(Color.hbMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.hbBackground)
            .navigationTitle("Settings")
        }
    }
}

struct TargetsForm: View {
    @AppStorage("hb.sleepTarget") private var sleepTarget = 7.5
    @AppStorage("hb.stepGoal") private var stepGoal = 8000.0
    @AppStorage("hb.protein") private var protein = 0.0

    var body: some View {
        Stepper("Sleep: \(hoursText(sleepTarget))", value: $sleepTarget, in: 5...10, step: 0.25)
        Stepper("Steps: \(Int(stepGoal).formatted())", value: $stepGoal, in: 2000...30000, step: 500)
        Stepper("Protein: \(protein > 0 ? "\(Int(protein)) g" : "Not set")", value: $protein, in: 0...400, step: 5)
    }
}

/// Every source, whether it's live, and how to connect what isn't.
struct ConnectionsView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                ConnectionRow(name: "Apple Health", status: healthStatus, live: health.hasRequestedAccess && health.hasAnyData)
                if !health.hasRequestedAccess {
                    Button("Connect Apple Health") { Task { await health.requestAccess() } }
                        .bold()
                } else {
                    Button("Open Health app permissions") { openURL(URL(string: "x-apple-health://")!) }
                    Text("If something is missing, open the Health app, tap your picture, then Apps, then Home Base, and turn on what you want shared.")
                        .font(.footnote).foregroundStyle(Color.hbMuted)
                }
                if let e = health.errorMessage { Text(e).font(.footnote).foregroundStyle(Color.hbWarn) }
            } footer: {
                Text("Live: new data arrives on its own, even when Home Base is closed.")
            }

            Section("Through Apple Health") {
                ConnectionRow(name: "Garmin", status: has("hrv") || !health.sleepNights.isEmpty ? "Data arriving" : "No data yet", live: has("hrv") || !health.sleepNights.isEmpty)
                Text("In Garmin Connect: More, Settings, Connected Apps, Apple Health. Turn on every category.")
                    .font(.footnote).foregroundStyle(Color.hbMuted)
                ConnectionRow(name: "MacroFactor", status: has("cal") ? "Data arriving" : "No data yet", live: has("cal"))
                Text("In MacroFactor: More, Integrations, Apple Health. Turn on writing nutrition.")
                    .font(.footnote).foregroundStyle(Color.hbMuted)
            }

            Section {
                ConnectionRow(name: "CIBC", status: "Coming next through Plaid", live: false)
            } footer: {
                Text("Needs a small Home Base server to hold the Plaid keys. Until then, the web version imports CIBC files.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.hbBackground)
        .navigationTitle("Connections")
        .refreshable { await health.refresh() }
    }

    private func has(_ id: String) -> Bool { !health.values(id).isEmpty }

    private var healthStatus: String {
        guard health.hasRequestedAccess else { return "Not connected" }
        guard let t = health.lastUpdated else { return "Connected" }
        return "Live · updated \(t.formatted(.relative(presentation: .named)))"
    }
}

struct ConnectionRow: View {
    let name: String
    let status: String
    let live: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(live ? Color.hbGood : Color.hbLine).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold))
                Text(status).font(.caption).foregroundStyle(Color.hbMuted)
            }
        }
    }
}

import SwiftUI

/// Things you can log by hand. Each one is saved straight to Apple Health.
struct QuickLog: Identifiable {
    let id: String
    let title: String
    let metricID: String?   // nil = mindful minutes
    let start: Double
    let step: Double
    let unit: String

    static let all: [QuickLog] = [
        .init(id: "water", title: "Water", metricID: "water", start: 8, step: 4, unit: "oz"),
        .init(id: "weight", title: "Weight", metricID: "weight", start: 180, step: 0.2, unit: "lb"),
        .init(id: "caffeine", title: "Caffeine", metricID: "caffeine", start: 95, step: 5, unit: "mg"),
        .init(id: "bodyfat", title: "Body fat", metricID: "bodyfat", start: 20, step: 0.1, unit: "%"),
        .init(id: "waist", title: "Waist", metricID: "waist", start: 34, step: 0.1, unit: "in"),
        .init(id: "mindful", title: "Mindful", metricID: nil, start: 10, step: 1, unit: "min"),
    ]
}

struct QuickLogRow: View {
    @Binding var logging: QuickLog?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log to Apple Health").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickLog.all) { log in
                        Button(log.title) { logging = log }
                            .buttonStyle(.bordered)
                            .tint(.hbMuted)
                    }
                }
            }
        }
        .card()
    }
}

struct QuickLogSheet: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.dismiss) private var dismiss
    let log: QuickLog
    @State private var value: Double = 0
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Log \(log.title.lowercased())").font(.title3.bold())
            HStack(spacing: 24) {
                stepButton("minus") { value = max(0, value - log.step) }
                Text("\(value.formatted(.number.precision(.fractionLength(log.step < 1 ? 1 : 0)))) \(log.unit)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .frame(minWidth: 160)
                stepButton("plus") { value += log.step }
            }
            if let error { Text(error).font(.caption).foregroundStyle(Color.hbWarn) }
            Button {
                Task { await save() }
            } label: {
                Text(saving ? "Saving…" : "Save to Apple Health").bold().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saving || value <= 0)
        }
        .padding(24)
        .presentationDetents([.height(260)])
        .onAppear {
            // start from your last value when there is one
            if let id = log.metricID, id != "water", id != "caffeine", let last = health.latest(id) {
                value = (last.value / log.step).rounded() * log.step
            } else {
                value = log.start
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2.bold()).frame(width: 52, height: 52)
                .background(Color.hbSurface2, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            if let id = log.metricID {
                try await health.save(HealthMetric.named(id), value: value)
            } else {
                try await health.saveMindful(minutes: value)
            }
            dismiss()
        } catch {
            self.error = "Couldn't save. Check that Home Base may write \(log.title.lowercased()) in the Health app under Sharing, Apps."
        }
    }
}

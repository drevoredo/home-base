import SwiftUI

// MARK: Run

struct RunView: View {
    @Environment(HealthStore.self) private var health
    @State private var logging = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("From your watch", systemImage: "applewatch.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.hbBlue)
                    Text("Runs from Garmin Connect arrive here on their own through Apple Health, with distance, pace and heart rate.")
                        .font(.subheadline).foregroundStyle(Color.hbMuted)
                }
                .card()

                HStack {
                    Text("Runs").font(.headline)
                    Spacer()
                    Button { logging = true } label: { Label("Log by hand", systemImage: "plus") }
                        .buttonStyle(.bordered)
                }
                if health.runs.isEmpty {
                    Text(health.hasRequestedAccess ? "No runs in the last 90 days yet." : "Connect Apple Health on Today to see your runs.")
                        .font(.subheadline).foregroundStyle(Color.hbMuted)
                }
                ForEach(health.runs) { run in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(run.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                .font(.subheadline.weight(.semibold))
                            Text("\(run.detailText) · \(run.source)").font(.caption).foregroundStyle(Color.hbMuted)
                        }
                        Spacer()
                        Text(String(format: "%.2f mi", run.miles)).font(.body.monospacedDigit().weight(.semibold))
                    }
                    .card()
                }
            }
            .padding(16)
        }
        .refreshable { await health.refresh() }
        .sheet(isPresented: $logging) { ManualRunSheet() }
    }
}

struct ManualRunSheet: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.dismiss) private var dismiss
    @State private var miles = 3.0
    @State private var minutes = 27
    @State private var seconds = 0
    @State private var indoor = false
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?

    private var totalSeconds: Double { Double(minutes * 60 + seconds) }
    private var pace: String {
        guard miles > 0 else { return "—" }
        let s = Int((totalSeconds / miles).rounded())
        return "\(s / 60):\(String(format: "%02d", s % 60)) /mi"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Distance: \(miles.formatted(.number.precision(.fractionLength(1)))) mi", value: $miles, in: 0.1...50, step: 0.1)
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 1...600)
                    Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59)
                    LabeledContent("Pace", value: pace)
                    Toggle("Treadmill", isOn: $indoor)
                    DatePicker("Finished", selection: $date, in: ...Date.now)
                } footer: {
                    Text("Saved to Apple Health as a run. Only use this for runs your watch didn't record, so nothing is counted twice.")
                }
                if let error { Text(error).foregroundStyle(Color.hbWarn) }
            }
            .navigationTitle("Log a run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await health.saveManualRun(start: date.addingTimeInterval(-totalSeconds), seconds: totalSeconds, miles: miles, indoor: indoor)
            dismiss()
        } catch {
            self.error = "Apple Health didn't accept it. Check that Home Base can write workouts and distance in the Health app."
        }
    }
}

// MARK: Splits

struct SplitsView: View {
    var onStart: (SplitDay) -> Void
    @AppStorage("hb.activeSplit") private var activeSplit = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Active split")
                if let split = Splits.premade.first(where: { $0.name == activeSplit }) {
                    ActiveSplitCard(split: split, onStart: onStart)
                } else {
                    Text("No split yet. Pick one below and Today will show each day's plan.")
                        .font(.subheadline).foregroundStyle(Color.hbMuted).card()
                }
                SectionLabel(text: "Premade splits").padding(.top, 8)
                ForEach(Splits.premade) { split in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(split.name).font(.headline)
                                Text("\(split.summary) · \(split.goal)").font(.caption).foregroundStyle(Color.hbMuted)
                            }
                            Spacer()
                            if split.name == activeSplit {
                                Text("In use").font(.caption.weight(.semibold)).foregroundStyle(Color.hbGood)
                            } else {
                                Button("Use") { activeSplit = split.name }.buttonStyle(.bordered)
                            }
                        }
                        WeekStrip(split: split)
                    }
                    .card()
                }
                Text("Making your own split comes next.").font(.caption).foregroundStyle(Color.hbMuted)
            }
            .padding(16)
        }
    }
}

struct ActiveSplitCard: View {
    let split: Split
    var onStart: (SplitDay) -> Void

    var body: some View {
        let today = split.days[Splits.todayIndex]
        VStack(alignment: .leading, spacing: 10) {
            Text(split.name).font(.title3.bold())
            WeekStrip(split: split)
            Divider()
            SectionLabel(text: "Today")
            Text(today.label).font(.headline)
            if let run = today.run { Label(run, systemImage: "figure.run").font(.subheadline) }
            if !today.exercises.isEmpty {
                Text(today.exercises.joined(separator: ", ")).font(.subheadline).foregroundStyle(Color.hbMuted)
                Button { onStart(today) } label: { Text("Start \(today.label)").bold().frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .card()
    }
}

struct WeekStrip: View {
    let split: Split
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let d = split.days[i]
                VStack(spacing: 3) {
                    Text(Splits.weekdayLetters[i]).font(.caption2).foregroundStyle(Color.hbMuted)
                    Circle()
                        .fill(d.isRest ? Color.hbLine : !d.exercises.isEmpty ? Color.hbAccent : Color.hbBlue)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(i == Splits.todayIndex ? Color.primary : .clear, lineWidth: 2).padding(-3))
                    Text(d.isRest ? "Rest" : String(d.label.prefix(5)))
                        .font(.system(size: 9)).foregroundStyle(Color.hbMuted).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

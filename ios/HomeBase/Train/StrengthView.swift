import SwiftUI
import SwiftData

struct StrengthView: View {
    @Bindable var draft: LiftDraft
    var showSplits: () -> Void

    @Environment(HealthStore.self) private var health
    @Environment(\.modelContext) private var context
    @Query(sort: \LiftSession.date, order: .reverse) private var history: [LiftSession]
    @AppStorage("hb.activeSplit") private var activeSplit = ""
    @State private var addingExercise = false
    @State private var finishing = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if draft.isEmpty { startCard }
                ForEach($draft.exercises) { $ex in
                    ExerciseCard(exercise: $ex, last: lastSets(for: ex.name),
                                 onSetDone: { draft.started = draft.started ?? Date.now; draft.restEnds = Date.now.addingTimeInterval(Double(draft.restSeconds)) },
                                 onRemove: { draft.exercises.removeAll { $0.id == ex.id } })
                }
                Button { addingExercise = true } label: {
                    Label("Add exercise", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                if let message { Text(message).font(.footnote).foregroundStyle(Color.hbMuted) }

                Text("History").font(.headline).padding(.top, 10)
                if history.isEmpty {
                    Text("Workouts you finish are saved here and to Apple Health.").font(.subheadline).foregroundStyle(Color.hbMuted)
                }
                ForEach(history.prefix(10)) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(.subheadline.weight(.semibold))
                            Text("\(s.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(s.exercises.map(\.name).joined(separator: ", "))")
                                .font(.caption).foregroundStyle(Color.hbMuted).lineLimit(1)
                        }
                        Spacer()
                        Text("\(s.workingSetCount) sets · \(Int(s.volume).formatted()) lb").font(.caption.monospacedDigit()).foregroundStyle(Color.hbMuted)
                    }
                    .card()
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) { if !draft.isEmpty { dock } }
        .sheet(isPresented: $addingExercise) {
            ExercisePicker { name in draft.exercises.append(LoggedExercise(name: name, sets: defaultSets(for: name))) }
        }
        .onAppear(perform: prefill)
        .onChange(of: draft.exercises.count) { _, _ in prefill() }
    }

    // MARK: Start

    private var startCard: some View {
        let split = Splits.premade.first { $0.name == activeSplit }
        let day = split?.days[Splits.todayIndex]
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Today")
            if let split, let day {
                Text(day.label).font(.title3.bold())
                Text(day.isRest ? "Rest day in \(split.name)." : day.exercises.isEmpty ? "Run day: \(day.run ?? "")" : day.exercises.joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(Color.hbMuted)
                if !day.exercises.isEmpty {
                    Button {
                        draft.title = day.label
                        draft.exercises = day.exercises.map { LoggedExercise(name: $0, sets: defaultSets(for: $0)) }
                    } label: { Text("Start \(day.label)").bold().frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("No split yet").font(.title3.bold())
                Text("Pick a split to get a plan for each day, or add exercises below.").font(.subheadline).foregroundStyle(Color.hbMuted)
                Button("Pick a split", action: showSplits).buttonStyle(.bordered)
            }
        }
        .card()
    }

    // MARK: Dock

    private var dock: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(draft.doneSets)/\(draft.totalSets) sets").font(.subheadline.monospacedDigit().weight(.semibold))
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    if let ends = draft.restEnds, ends > ctx.date {
                        let s = Int(ends.timeIntervalSince(ctx.date).rounded(.up))
                        Text("Rest \(s / 60):\(String(format: "%02d", s % 60))").font(.caption.monospacedDigit()).foregroundStyle(Color.hbAccent)
                    } else if let start = draft.started {
                        Text(start, style: .timer).font(.caption.monospacedDigit()).foregroundStyle(Color.hbMuted)
                    } else {
                        Text("Check off a set to start").font(.caption).foregroundStyle(Color.hbMuted)
                    }
                }
            }
            Spacer()
            Menu {
                Button("Discard workout", role: .destructive) { draft.reset() }
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }
            Button {
                Task { await finish() }
            } label: { Text(finishing ? "Saving…" : "Finish").bold().padding(.horizontal, 10) }
            .buttonStyle(.borderedProminent)
            .disabled(finishing || draft.doneSets == 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func finish() async {
        finishing = true
        defer { finishing = false }
        let exercises = draft.exercises.compactMap { ex -> LoggedExercise? in
            let sets = ex.sets.filter(\.done)
            return sets.isEmpty ? nil : LoggedExercise(name: ex.name, sets: sets)
        }
        let end = Date.now
        let start = min(draft.started ?? end, end.addingTimeInterval(-60))
        let session = LiftSession(date: start, title: draft.title, minutes: max(1, Int(end.timeIntervalSince(start) / 60)), exercises: exercises)
        context.insert(session)
        try? context.save()
        do {
            try await health.saveStrengthWorkout(start: start, end: end)
            message = "Saved \(session.title): \(session.workingSetCount) working sets, \(Int(session.volume).formatted()) lb. Also saved to Apple Health."
        } catch {
            message = "Saved \(session.title) on this iPhone. Apple Health didn't accept it; check Home Base can write workouts in the Health app."
        }
        draft.reset()
    }

    // MARK: Last session

    /// Working sets from the last time you did this exercise.
    private func lastSets(for name: String) -> [LoggedSet] {
        for s in history {
            if let ex = s.exercises.first(where: { $0.name == name }), !ex.workingSets.isEmpty { return ex.workingSets }
        }
        return []
    }

    /// Last session's numbers to beat, or three blank sets of 8 the first time.
    private func defaultSets(for name: String) -> [LoggedSet] {
        let last = lastSets(for: name)
        if last.isEmpty { return (0..<3).map { _ in LoggedSet() } }
        return last.map { LoggedSet(weight: $0.weight, reps: $0.reps) }
    }

    private func prefill() {
        for i in draft.exercises.indices where draft.exercises[i].sets.isEmpty {
            draft.exercises[i].sets = defaultSets(for: draft.exercises[i].name)
        }
    }
}

// MARK: One exercise

struct ExerciseCard: View {
    @Binding var exercise: LoggedExercise
    let last: [LoggedSet]
    var onSetDone: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name).font(.headline)
                Spacer()
                Menu {
                    Button("Add warm-up sets") { addWarmups() }
                    Button("Remove exercise", role: .destructive, action: onRemove)
                } label: { Image(systemName: "ellipsis").padding(6) }
            }
            if !last.isEmpty {
                Text("Last time: " + last.map { "\(fmt($0.weight))×\($0.reps)" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(Color.hbMuted)
            }
            HStack {
                Text("SET").frame(width: 34)
                Text("LB").frame(maxWidth: .infinity)
                Text("REPS").frame(width: 110)
                Spacer().frame(width: 40)
            }
            .font(.caption2.weight(.semibold)).foregroundStyle(Color.hbMuted)

            ForEach($exercise.sets) { $set in
                let n = (exercise.sets.filter { !$0.warmup }.firstIndex { $0.id == set.id } ?? 0) + 1
                HStack {
                    Button { set.warmup.toggle() } label: {
                        Text(set.warmup ? "W" : "\(n)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(set.warmup ? Color.hbAmber : .primary)
                            .frame(width: 34, height: 34)
                            .background(Color.hbSurface2, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    TextField("0", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.body.monospacedDigit())
                        .padding(.vertical, 7)
                        .background(Color.hbSurface2, in: RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 0) {
                        Button { if set.reps > 1 { set.reps -= 1 } } label: { Image(systemName: "minus").frame(width: 32, height: 34) }
                        Text("\(set.reps)").font(.body.monospacedDigit()).frame(width: 36)
                        Button { set.reps += 1 } label: { Image(systemName: "plus").frame(width: 32, height: 34) }
                    }
                    .buttonStyle(.plain)
                    .background(Color.hbSurface2, in: RoundedRectangle(cornerRadius: 8))
                    .frame(width: 110)
                    Button {
                        set.done.toggle()
                        if set.done { onSetDone() }
                    } label: {
                        Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(set.done ? Color.hbGood : Color.hbLine)
                            .frame(width: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                let copy = exercise.sets.last.map { LoggedSet(warmup: false, weight: $0.weight, reps: $0.reps) } ?? LoggedSet()
                exercise.sets.append(copy)
            } label: { Label("Add set", systemImage: "plus").font(.subheadline) }
            .buttonStyle(.borderless)
        }
        .card()
    }

    /// 50% × 8 and 75% × 3 of the first working weight, rounded to 5 lb.
    private func addWarmups() {
        guard let top = exercise.sets.first(where: { !$0.warmup })?.weight, top > 45 else { return }
        let round5 = { (w: Double) in (w / 5).rounded() * 5 }
        let warm = [LoggedSet(warmup: true, weight: round5(top * 0.5), reps: 8), LoggedSet(warmup: true, weight: round5(top * 0.75), reps: 3)]
        exercise.sets.insert(contentsOf: warm, at: 0)
    }

    private func fmt(_ w: Double) -> String { w.formatted(.number.precision(.fractionLength(0...1))) }
}

// MARK: Picker

struct ExercisePicker: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty && !Splits.commonExercises.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) {
                    Button("Add \"\(query)\"") { pick(query.trimmingCharacters(in: .whitespaces)) }
                }
                ForEach(Splits.commonExercises.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { name in
                    Button(name) { pick(name) }.foregroundStyle(.primary)
                }
            }
            .searchable(text: $query, prompt: "Search or type a new exercise")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func pick(_ name: String) { onPick(name); dismiss() }
}

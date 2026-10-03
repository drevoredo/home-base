import SwiftUI
import SwiftData

/// The workout being logged right now. Lives as long as the app, so switching tabs doesn't lose it.
@Observable
final class LiftDraft {
    var title = "Workout"
    var exercises: [LoggedExercise] = []
    var started: Date?
    var restEnds: Date?
    var restSeconds = 90

    var isEmpty: Bool { exercises.isEmpty }
    var doneSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.done).count } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    func reset() {
        title = "Workout"; exercises = []; started = nil; restEnds = nil
    }
}

struct TrainView: View {
    enum Tab: String, CaseIterable { case strength = "Strength", run = "Run", splits = "Splits" }
    @State private var tab: Tab = .strength
    @State private var draft = LiftDraft()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                switch tab {
                case .strength: StrengthView(draft: draft, showSplits: { tab = .splits })
                case .run: RunView()
                case .splits: SplitsView(onStart: { start($0) })
                }
            }
            .background(Color.hbBackground)
            .navigationTitle(tab == .strength ? draft.title : tab.rawValue)
        }
    }

    private func start(_ day: SplitDay) {
        draft.reset()
        draft.title = day.label
        draft.exercises = day.exercises.map { LoggedExercise(name: $0, sets: []) }
        tab = .strength
    }
}

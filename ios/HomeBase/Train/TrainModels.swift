import Foundation
import SwiftData

// MARK: Logged workouts (saved on the iPhone with SwiftData)

struct LoggedSet: Codable, Hashable, Identifiable {
    var id = UUID()
    var warmup = false
    var weight: Double = 0
    var reps: Int = 8
    var done = false
}

struct LoggedExercise: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var sets: [LoggedSet]

    var workingSets: [LoggedSet] { sets.filter { $0.done && !$0.warmup } }
    var volume: Double { workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
    /// Epley estimate from the best working set.
    var estimatedMax: Double { workingSets.map { $0.weight * (1 + Double($0.reps) / 30) }.max() ?? 0 }
}

@Model
final class LiftSession {
    var date: Date
    var title: String
    var minutes: Int
    /// Exercises stored as JSON so the model stays simple across app updates.
    var exercisesData: Data

    init(date: Date, title: String, minutes: Int, exercises: [LoggedExercise]) {
        self.date = date
        self.title = title
        self.minutes = minutes
        self.exercisesData = (try? JSONEncoder().encode(exercises)) ?? Data()
    }

    var exercises: [LoggedExercise] {
        (try? JSONDecoder().decode([LoggedExercise].self, from: exercisesData)) ?? []
    }
    var workingSetCount: Int { exercises.reduce(0) { $0 + $1.workingSets.count } }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
}

// MARK: Splits

struct SplitDay: Hashable, Codable {
    var label: String          // "Upper A", "Rest"
    var exercises: [String]
    var run: String?           // "Easy 30 min"

    static let rest = SplitDay(label: "Rest", exercises: [])
    var isRest: Bool { exercises.isEmpty && run == nil }
}

struct Split: Identifiable, Hashable, Codable {
    var id: String { name }
    var name: String
    var summary: String
    var goal: String
    /// Monday first, 7 entries.
    var days: [SplitDay]

    var liftDays: Int { days.filter { !$0.exercises.isEmpty }.count }
    var runDays: Int { days.filter { $0.run != nil }.count }
}

enum Splits {
    static let upperA = ["Bench press", "Barbell row", "Overhead press", "Lat pulldown", "Dumbbell curl", "Triceps pushdown"]
    static let upperB = ["Incline dumbbell press", "Pull-up", "Seated cable row", "Lateral raise", "Face pull"]
    static let lowerA = ["Back squat", "Romanian deadlift", "Leg press", "Leg curl", "Calf raise"]
    static let lowerB = ["Deadlift", "Front squat", "Walking lunge", "Leg extension", "Plank"]
    static let push = ["Bench press", "Overhead press", "Incline dumbbell press", "Lateral raise", "Triceps pushdown"]
    static let pull = ["Deadlift", "Pull-up", "Barbell row", "Face pull", "Dumbbell curl"]
    static let legs = ["Back squat", "Romanian deadlift", "Leg press", "Leg curl", "Calf raise"]
    static let full = ["Back squat", "Bench press", "Barbell row", "Overhead press", "Romanian deadlift"]

    static let premade: [Split] = [
        Split(name: "Hybrid 4 + 3", summary: "Upper/lower lifting with three runs", goal: "Hybrid", days: [
            SplitDay(label: "Upper A", exercises: upperA),
            SplitDay(label: "Easy run", exercises: [], run: "Easy 30–40 min"),
            SplitDay(label: "Lower A", exercises: lowerA),
            SplitDay(label: "Tempo run", exercises: [], run: "Tempo 20 min"),
            SplitDay(label: "Upper B", exercises: upperB),
            SplitDay(label: "Lower B + long run", exercises: lowerB, run: "Long run 60+ min"),
            .rest]),
        Split(name: "Upper / Lower", summary: "Four lifting days, two easy runs", goal: "Strength", days: [
            SplitDay(label: "Upper A", exercises: upperA),
            SplitDay(label: "Lower A", exercises: lowerA),
            SplitDay(label: "Easy run", exercises: [], run: "Easy 30 min"),
            SplitDay(label: "Upper B", exercises: upperB),
            SplitDay(label: "Lower B", exercises: lowerB),
            SplitDay(label: "Easy run", exercises: [], run: "Easy 30 min"),
            .rest]),
        Split(name: "Push / Pull / Legs", summary: "Six lifting days for muscle", goal: "Muscle", days: [
            SplitDay(label: "Push", exercises: push),
            SplitDay(label: "Pull", exercises: pull),
            SplitDay(label: "Legs", exercises: legs),
            SplitDay(label: "Push", exercises: push),
            SplitDay(label: "Pull", exercises: pull),
            SplitDay(label: "Legs", exercises: legs),
            .rest]),
        Split(name: "Full body 3 + 2", summary: "Three full-body days, two runs", goal: "General", days: [
            SplitDay(label: "Full body", exercises: full),
            SplitDay(label: "Easy run", exercises: [], run: "Easy 30 min"),
            SplitDay(label: "Full body", exercises: full),
            .rest,
            SplitDay(label: "Full body", exercises: full),
            SplitDay(label: "Long run", exercises: [], run: "Long run 45–60 min"),
            .rest]),
        Split(name: "Run focus", summary: "Four runs, two short lifts", goal: "Running", days: [
            SplitDay(label: "Easy run", exercises: [], run: "Easy 40 min"),
            SplitDay(label: "Full body", exercises: ["Back squat", "Romanian deadlift", "Pull-up", "Plank"]),
            SplitDay(label: "Intervals", exercises: [], run: "6 × 800 m"),
            .rest,
            SplitDay(label: "Tempo run", exercises: [], run: "Tempo 25 min"),
            SplitDay(label: "Long run", exercises: [], run: "Long run 75+ min"),
            SplitDay(label: "Lift", exercises: ["Deadlift", "Walking lunge", "Calf raise", "Plank"])]),
    ]

    static let commonExercises = Array(Set(upperA + upperB + lowerA + lowerB + push + pull + legs + full)).sorted()

    /// 0 = Monday … 6 = Sunday.
    static var todayIndex: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }
    static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
}

import HealthKit

/// How a metric's samples combine into one value per day.
enum Aggregation {
    case sum, average, latest
}

/// One Apple Health quantity Home Base shows. Mirrors the "All health data" catalog in the web prototype.
struct HealthMetric: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String
    let identifier: HKQuantityTypeIdentifier
    let unit: HKUnit
    let unitLabel: String
    let aggregation: Aggregation
    /// Home Base can save this type to Apple Health.
    var writable = false
    /// Multiplier from the HealthKit unit to what we display (percent types come back as 0–1).
    var scale: Double = 1

    var quantityType: HKQuantityType { HKQuantityType(identifier) }

    static func == (a: HealthMetric, b: HealthMetric) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    func format(_ v: Double) -> String {
        switch id {
        case "steps", "flights", "energy", "cal":
            return v.formatted(.number.precision(.fractionLength(0)))
        case "weight", "lean", "waist", "bodyfat", "dist", "bmi", "stride", "vosc", "vo2":
            return v.formatted(.number.precision(.fractionLength(1)))
        default:
            return v.formatted(.number.precision(.fractionLength(0)))
        }
    }

    func formatWithUnit(_ v: Double) -> String {
        unitLabel.isEmpty ? format(v) : "\(format(v)) \(unitLabel)"
    }
}

extension HealthMetric {
    static let bpm = HKUnit.count().unitDivided(by: .minute())

    static let all: [HealthMetric] = [
        // Activity
        .init(id: "steps", name: "Steps", group: "Activity", identifier: .stepCount, unit: .count(), unitLabel: "", aggregation: .sum),
        .init(id: "dist", name: "Walking + running distance", group: "Activity", identifier: .distanceWalkingRunning, unit: .mile(), unitLabel: "mi", aggregation: .sum),
        .init(id: "energy", name: "Active energy", group: "Activity", identifier: .activeEnergyBurned, unit: .kilocalorie(), unitLabel: "kcal", aggregation: .sum),
        .init(id: "exmin", name: "Exercise minutes", group: "Activity", identifier: .appleExerciseTime, unit: .minute(), unitLabel: "min", aggregation: .sum),
        .init(id: "flights", name: "Flights climbed", group: "Activity", identifier: .flightsClimbed, unit: .count(), unitLabel: "", aggregation: .sum),
        .init(id: "vo2", name: "VO2 max", group: "Activity", identifier: .vo2Max, unit: HKUnit(from: "ml/kg*min"), unitLabel: "ml/kg/min", aggregation: .latest),
        // Heart
        .init(id: "hrv", name: "HRV", group: "Heart", identifier: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), unitLabel: "ms", aggregation: .average),
        .init(id: "rhr", name: "Resting heart rate", group: "Heart", identifier: .restingHeartRate, unit: bpm, unitLabel: "bpm", aggregation: .average),
        .init(id: "walkhr", name: "Walking heart rate", group: "Heart", identifier: .walkingHeartRateAverage, unit: bpm, unitLabel: "bpm", aggregation: .average),
        .init(id: "resp", name: "Respiratory rate", group: "Heart", identifier: .respiratoryRate, unit: bpm, unitLabel: "br/min", aggregation: .average),
        .init(id: "spo2", name: "Blood oxygen", group: "Heart", identifier: .oxygenSaturation, unit: .percent(), unitLabel: "%", aggregation: .average, scale: 100),
        // Body
        .init(id: "weight", name: "Weight", group: "Body", identifier: .bodyMass, unit: .pound(), unitLabel: "lb", aggregation: .latest, writable: true),
        .init(id: "bodyfat", name: "Body fat", group: "Body", identifier: .bodyFatPercentage, unit: .percent(), unitLabel: "%", aggregation: .latest, writable: true, scale: 100),
        .init(id: "lean", name: "Lean body mass", group: "Body", identifier: .leanBodyMass, unit: .pound(), unitLabel: "lb", aggregation: .latest),
        .init(id: "waist", name: "Waist", group: "Body", identifier: .waistCircumference, unit: .inch(), unitLabel: "in", aggregation: .latest, writable: true),
        .init(id: "bmi", name: "BMI", group: "Body", identifier: .bodyMassIndex, unit: .count(), unitLabel: "", aggregation: .latest),
        // Nutrition (MacroFactor writes these)
        .init(id: "cal", name: "Calories eaten", group: "Nutrition", identifier: .dietaryEnergyConsumed, unit: .kilocalorie(), unitLabel: "kcal", aggregation: .sum),
        .init(id: "protein", name: "Protein", group: "Nutrition", identifier: .dietaryProtein, unit: .gram(), unitLabel: "g", aggregation: .sum),
        .init(id: "carbs", name: "Carbs", group: "Nutrition", identifier: .dietaryCarbohydrates, unit: .gram(), unitLabel: "g", aggregation: .sum),
        .init(id: "fat", name: "Fat", group: "Nutrition", identifier: .dietaryFatTotal, unit: .gram(), unitLabel: "g", aggregation: .sum),
        .init(id: "water", name: "Water", group: "Nutrition", identifier: .dietaryWater, unit: .fluidOunceUS(), unitLabel: "oz", aggregation: .sum, writable: true),
        .init(id: "caffeine", name: "Caffeine", group: "Nutrition", identifier: .dietaryCaffeine, unit: .gramUnit(with: .milli), unitLabel: "mg", aggregation: .sum, writable: true),
        // Vitals
        .init(id: "bp", name: "Blood pressure (systolic)", group: "Vitals", identifier: .bloodPressureSystolic, unit: .millimeterOfMercury(), unitLabel: "mmHg", aggregation: .average),
        .init(id: "glucose", name: "Blood glucose", group: "Vitals", identifier: .bloodGlucose, unit: HKUnit(from: "mg/dL"), unitLabel: "mg/dL", aggregation: .average),
        // Running form
        .init(id: "rpower", name: "Running power", group: "Running form", identifier: .runningPower, unit: .watt(), unitLabel: "W", aggregation: .average),
        .init(id: "stride", name: "Stride length", group: "Running form", identifier: .runningStrideLength, unit: .foot(), unitLabel: "ft", aggregation: .average),
        .init(id: "gct", name: "Ground contact time", group: "Running form", identifier: .runningGroundContactTime, unit: .secondUnit(with: .milli), unitLabel: "ms", aggregation: .average),
        .init(id: "vosc", name: "Vertical oscillation", group: "Running form", identifier: .runningVerticalOscillation, unit: .inch(), unitLabel: "in", aggregation: .average),
    ]

    static let groups = ["Activity", "Heart", "Body", "Nutrition", "Vitals", "Running form"]

    static func named(_ id: String) -> HealthMetric { all.first { $0.id == id }! }
}

/// One value for one day.
struct DayValue: Identifiable, Hashable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Last night's sleep split into stages, in hours.
struct SleepNight: Identifiable, Hashable {
    let night: Date
    var core = 0.0, deep = 0.0, rem = 0.0, unspecified = 0.0, awake = 0.0, inBed = 0.0
    var id: Date { night }
    var asleep: Double { core + deep + rem + unspecified }
}

/// A run pulled from Apple Health (Garmin Connect writes these).
struct RunSummary: Identifiable, Hashable {
    let id: UUID
    let start: Date
    let miles: Double
    let seconds: Double
    let avgHeartRate: Double?
    let source: String

    var paceText: String {
        guard miles > 0 else { return "—" }
        let s = Int((seconds / miles).rounded())
        return String(format: "%d:%02d /mi", s / 60, s % 60)
    }
    var detailText: String {
        var parts = [durationText, paceText]
        if let hr = avgHeartRate { parts.append("\(Int(hr.rounded())) bpm") }
        return parts.joined(separator: " · ")
    }
    var durationText: String {
        let s = Int(seconds.rounded())
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

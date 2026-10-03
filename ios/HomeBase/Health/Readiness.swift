import SwiftUI

/// Readiness from last night's sleep, HRV and resting heart rate against the last 4 weeks.
/// Same formula as the web prototype so both show the same score.
struct Readiness {
    struct Driver: Identifiable {
        let name: String
        let detail: String
        let good: Bool
        var id: String { name }
    }

    let score: Int
    let state: String
    let color: Color
    let advice: String
    let drivers: [Driver]

    static func compute(from health: HealthStore, sleepNeed: Double = 7.5) -> Readiness? {
        guard let sleep = health.lastNight?.asleep,
              let hrv = recent(health.values("hrv")),
              let rhr = recent(health.values("rhr")),
              let hrvBase = baseline(health.values("hrv")),
              let rhrBase = baseline(health.values("rhr"))
        else { return nil }

        let raw = 72 + (sleep - sleepNeed) * 12 + (hrv - hrvBase) / hrvBase * 100 - (rhr - rhrBase) * 3
        let score = Int(max(0, min(100, raw)).rounded())
        let (state, color, advice): (String, Color, String) =
            score >= 70 ? ("Ready", Color.hbGood, "Train as planned.") :
            score >= 50 ? ("Go easier", Color.hbWarn, "Train, but keep it easy: drop a set or slow the pace.") :
                          ("Recover", Color.hbBad, "Make today a rest or walking day.")
        return Readiness(score: score, state: state, color: color, advice: advice, drivers: [
            .init(name: "Sleep", detail: "\(hoursText(sleep)) of \(hoursText(sleepNeed)) need", good: sleep >= sleepNeed),
            .init(name: "HRV", detail: "\(Int(hrv.rounded())) ms, \(hrv >= hrvBase ? "above" : "below") your \(Int(hrvBase.rounded())) ms average", good: hrv >= hrvBase - 2),
            .init(name: "Resting HR", detail: "\(Int(rhr.rounded())) bpm, \(rhr <= rhrBase ? "at or below" : "above") your \(Int(rhrBase.rounded())) bpm average", good: rhr <= rhrBase + 1),
        ])
    }

    /// Today's value, or yesterday's if today hasn't synced yet.
    private static func recent(_ v: [DayValue]) -> Double? {
        guard let last = v.last else { return nil }
        let cal = Calendar.current
        return cal.isDateInToday(last.date) || cal.isDateInYesterday(last.date) ? last.value : nil
    }

    /// Average of the 28 days before today; needs at least 5 days.
    private static func baseline(_ v: [DayValue]) -> Double? {
        let today = Calendar.current.startOfDay(for: .now)
        let from = Calendar.current.date(byAdding: .day, value: -28, to: today)!
        let window = v.filter { $0.date >= from && $0.date < today }.map(\.value)
        return window.count >= 5 ? window.reduce(0, +) / Double(window.count) : nil
    }
}

func hoursText(_ h: Double) -> String {
    let total = Int((h * 60).rounded())
    return "\(total / 60)h \(String(format: "%02d", total % 60))m"
}

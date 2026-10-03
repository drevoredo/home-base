import Foundation
import HealthKit
import Observation

/// Live connection to Apple Health: asks for access, reads everything Home Base shows,
/// keeps it fresh with observer queries (also in the background), and saves quick logs.
@MainActor
@Observable
final class HealthStore {
    static let shared = HealthStore()

    let store = HKHealthStore()

    /// Last 90 days, one value per day, keyed by HealthMetric.id.
    var series: [String: [DayValue]] = [:]
    var sleepNights: [SleepNight] = []
    var runs: [RunSummary] = []
    var lastUpdated: Date?
    var isRefreshing = false
    var errorMessage: String?
    var hasRequestedAccess = UserDefaults.standard.bool(forKey: "hb.healthRequested")

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    @ObservationIgnored private var observing = false
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    private let days = 90

    // MARK: Types

    private var sleepType: HKCategoryType { HKCategoryType(.sleepAnalysis) }
    private var mindfulType: HKCategoryType { HKCategoryType(.mindfulSession) }

    private var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>(HealthMetric.all.map(\.quantityType))
        s.insert(sleepType)
        s.insert(mindfulType)
        s.insert(HKObjectType.workoutType())
        s.insert(HKQuantityType(.heartRate))
        return s
    }

    private var shareTypes: Set<HKSampleType> {
        var s = Set<HKSampleType>(HealthMetric.all.filter(\.writable).map(\.quantityType))
        s.insert(mindfulType)
        s.insert(HKObjectType.workoutType())
        s.insert(HKQuantityType(.distanceWalkingRunning))   // hand-entered runs
        return s
    }

    /// Types whose changes trigger a refresh. Kept short: each one wakes the app.
    private var observedTypes: [HKSampleType] {
        [sleepType, HKObjectType.workoutType()] +
        ["steps", "hrv", "rhr", "weight", "cal", "water"].map { HealthMetric.named($0).quantityType }
    }

    // MARK: Access

    func requestAccess() async {
        guard isAvailable else {
            errorMessage = "Apple Health isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            hasRequestedAccess = true
            UserDefaults.standard.set(true, forKey: "hb.healthRequested")
            startObserving()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Call at launch. Re-registers observers so background delivery keeps working.
    func startIfAuthorized() {
        guard isAvailable, hasRequestedAccess else { return }
        startObserving()
        Task { await refresh() }
    }

    private func startObserving() {
        guard !observing else { return }
        observing = true
        for type in observedTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                if error != nil { completion(); return }
                Task { @MainActor in
                    self?.scheduleRefresh()
                    completion()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }

    /// Several types often change together (a run brings HR, distance and energy), so wait a moment and refresh once.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    // MARK: Reading

    func refresh() async {
        guard isAvailable, hasRequestedAccess, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!

        var newSeries: [String: [DayValue]] = [:]
        await withTaskGroup(of: (String, [DayValue]).self) { group in
            for metric in HealthMetric.all {
                group.addTask { [store] in
                    let values = (try? await Self.daily(metric, from: start, store: store)) ?? []
                    return (metric.id, values)
                }
            }
            for await (id, values) in group { newSeries[id] = values }
        }
        series = newSeries
        sleepNights = (try? await loadSleep(from: start)) ?? []
        runs = (try? await loadRuns(from: start)) ?? []
        lastUpdated = .now
    }

    nonisolated private static func daily(_ m: HealthMetric, from start: Date, store: HKHealthStore) async throws -> [DayValue] {
        let options: HKStatisticsOptions
        switch m.aggregation {
        case .sum: options = .cumulativeSum
        case .average: options = .discreteAverage
        case .latest: options = .mostRecent
        }
        let predicate = HKSamplePredicate.quantitySample(
            type: m.quantityType,
            predicate: HKQuery.predicateForSamples(withStart: start, end: nil))
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: options,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1))
        let collection = try await descriptor.result(for: store)
        var out: [DayValue] = []
        collection.enumerateStatistics(from: start, to: .now) { stats, _ in
            let q: HKQuantity?
            switch m.aggregation {
            case .sum: q = stats.sumQuantity()
            case .average: q = stats.averageQuantity()
            case .latest: q = stats.mostRecentQuantity()
            }
            if let q { out.append(DayValue(date: stats.startDate, value: q.doubleValue(for: m.unit) * m.scale)) }
        }
        return out
    }

    /// Sleep grouped by the morning it ended. When two apps both record a night (watch and iPhone),
    /// keep the one with the most sleep instead of adding them together.
    private func loadSleep(from start: Date) async throws -> [SleepNight] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.endDate)])
        let samples = try await descriptor.result(for: store)
        var bySource: [Date: [String: SleepNight]] = [:]
        let cal = Calendar.current
        for s in samples {
            let night = cal.startOfDay(for: s.endDate)
            let src = s.sourceRevision.source.bundleIdentifier
            var n = bySource[night]?[src] ?? SleepNight(night: night)
            let hours = s.endDate.timeIntervalSince(s.startDate) / 3600
            switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
            case .asleepCore: n.core += hours
            case .asleepDeep: n.deep += hours
            case .asleepREM: n.rem += hours
            case .asleepUnspecified: n.unspecified += hours
            case .awake: n.awake += hours
            case .inBed: n.inBed += hours
            default: break
            }
            bySource[night, default: [:]][src] = n
        }
        return bySource.compactMap { _, sources in sources.values.max { $0.asleep < $1.asleep } }
            .filter { $0.asleep > 0 }
            .sorted { $0.night < $1.night }
    }

    private func loadRuns(from start: Date) async throws -> [RunSummary] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: start, end: nil),
        ])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = try await descriptor.result(for: store)
        return workouts.map { w in
            let miles = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .mile()) ?? 0
            let hr = w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HealthMetric.bpm)
            return RunSummary(id: w.uuid, start: w.startDate, miles: miles, seconds: w.duration, avgHeartRate: hr, source: w.sourceRevision.source.name)
        }
    }

    // MARK: Convenience

    func values(_ id: String) -> [DayValue] { series[id] ?? [] }
    func latest(_ id: String) -> DayValue? { values(id).last }
    var lastNight: SleepNight? {
        guard let n = sleepNights.last, Calendar.current.isDateInToday(n.night) || Calendar.current.isDateInYesterday(n.night) else { return nil }
        return n
    }
    var hasAnyData: Bool { series.values.contains { !$0.isEmpty } || !sleepNights.isEmpty || !runs.isEmpty }

    // MARK: Writing

    func save(_ metric: HealthMetric, value: Double, date: Date = .now) async throws {
        let quantity = HKQuantity(unit: metric.unit, doubleValue: value / metric.scale)
        let sample = HKQuantitySample(type: metric.quantityType, quantity: quantity, start: date, end: date)
        try await store.save(sample)
        await refresh()
    }

    func saveMindful(minutes: Double) async throws {
        let end = Date.now
        let sample = HKCategorySample(type: mindfulType, value: HKCategoryValue.notApplicable.rawValue,
                                      start: end.addingTimeInterval(-minutes * 60), end: end)
        try await store.save(sample)
    }

    /// Whether Home Base may write this type. (Apple never reveals read permission, only write.)
    func canWrite(_ metric: HealthMetric) -> Bool {
        store.authorizationStatus(for: metric.quantityType) == .sharingAuthorized
    }
}

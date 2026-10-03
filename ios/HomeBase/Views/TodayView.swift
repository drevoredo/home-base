import SwiftUI
import Charts

struct TodayView: View {
    @Environment(HealthStore.self) private var health
    @State private var logging: QuickLog?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !health.hasRequestedAccess {
                        ConnectHealthCard()
                    }
                    ReadinessCard()
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        SleepTile()
                        MetricTile(id: "hrv", color: .hbGreen)
                        MetricTile(id: "rhr", color: .hbPink)
                        MetricTile(id: "steps", color: .hbAmber)
                    }
                    QuickLogRow(logging: $logging)
                    RecentRunsCard()
                    AllHealthDataCard()
                    if let t = health.lastUpdated {
                        Text("Updated from Apple Health \(t.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(Color.hbMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
            .background(Color.hbBackground)
            .navigationTitle("Today")
            .refreshable { await health.refresh() }
            .sheet(item: $logging) { QuickLogSheet(log: $0) }
        }
    }
}

// MARK: Connect

struct ConnectHealthCard: View {
    @Environment(HealthStore.self) private var health
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                .font(.headline).foregroundStyle(Color.hbAccent)
            Text("Home Base reads your Garmin runs, sleep, HRV, heart rate, steps, weight and MacroFactor food from Apple Health, and keeps it up to date on its own.")
                .font(.subheadline).foregroundStyle(Color.hbMuted)
            Button {
                Task { await health.requestAccess() }
            } label: {
                Text("Connect").bold().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            if let e = health.errorMessage {
                Text(e).font(.caption).foregroundStyle(Color.hbWarn)
            }
        }
        .card()
    }
}

// MARK: Readiness

struct ReadinessCard: View {
    @Environment(HealthStore.self) private var health
    @AppStorage("hb.sleepTarget") private var sleepTarget = 7.5

    var body: some View {
        let r = Readiness.compute(from: health, sleepNeed: sleepTarget)
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().stroke(Color.hbLine, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(r?.score ?? 0) / 100)
                    .stroke(r?.color ?? .hbLine, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: r?.score)
                Text(r.map { "\($0.score)" } ?? "—")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Readiness")
                Text(r?.state ?? "Waiting for data")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(r?.color ?? .hbMuted)
                if let r {
                    ForEach(r.drivers) { d in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: d.good ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.caption2).foregroundStyle(d.good ? Color.hbGood : Color.hbWarn)
                            (Text(d.name + " ").bold() + Text(d.detail)).font(.caption)
                        }
                    }
                    Text(r.advice).font(.caption).foregroundStyle(Color.hbMuted)
                } else {
                    Text("Built from last night's sleep, HRV and resting heart rate against your last 4 weeks. It needs about a week of data from your watch.")
                        .font(.caption).foregroundStyle(Color.hbMuted)
                }
            }
        }
        .card()
    }
}

// MARK: Tiles

struct MetricTile: View {
    @Environment(HealthStore.self) private var health
    let id: String
    let color: Color

    var body: some View {
        let m = HealthMetric.named(id)
        let values = Array(health.values(id).suffix(14))
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
                SectionLabel(text: m.id == "rhr" ? "Resting HR" : m.name)
            }
            Text(values.last.map { m.formatWithUnit($0.value) } ?? "—")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
            Sparkline(values: values, color: color)
                .frame(height: 30)
        }
        .card()
    }
}

struct SleepTile: View {
    @Environment(HealthStore.self) private var health
    var body: some View {
        let nights = Array(health.sleepNights.suffix(14))
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.hbBlue).frame(width: 8, height: 8)
                SectionLabel(text: "Sleep")
            }
            Text(health.lastNight.map { hoursText($0.asleep) } ?? "—")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
            Sparkline(values: nights.map { DayValue(date: $0.night, value: $0.asleep) }, color: .hbBlue)
                .frame(height: 30)
        }
        .card()
    }
}

struct Sparkline: View {
    let values: [DayValue]
    let color: Color
    var body: some View {
        if values.count < 2 {
            Text(values.isEmpty ? "No data yet" : "Latest").font(.caption2).foregroundStyle(Color.hbMuted)
        } else {
            Chart(values) {
                LineMark(x: .value("Day", $0.date), y: .value("Value", $0.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
        }
    }
}

// MARK: Runs

struct RecentRunsCard: View {
    @Environment(HealthStore.self) private var health
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent runs").font(.headline)
            if health.runs.isEmpty {
                Text("Runs from your Garmin show up here automatically.").font(.subheadline).foregroundStyle(Color.hbMuted)
            }
            ForEach(health.runs.prefix(5)) { run in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())).font(.subheadline.weight(.semibold))
                        Text(run.detailText)
                            .font(.caption).foregroundStyle(Color.hbMuted)
                    }
                    Spacer()
                    Text(String(format: "%.2f mi", run.miles)).font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 4)
            }
        }
        .card()
    }
}

// MARK: All data

struct AllHealthDataCard: View {
    @Environment(HealthStore.self) private var health
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All health data").font(.headline)
            ForEach(HealthMetric.groups, id: \.self) { group in
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: group)
                    ForEach(HealthMetric.all.filter { $0.group == group }) { m in
                        HStack {
                            Text(m.name).font(.subheadline)
                            if m.writable {
                                Text("Write").font(.caption2.weight(.semibold)).padding(.horizontal, 5).padding(.vertical, 1)
                                    .overlay(Capsule().stroke(Color.hbLine)).foregroundStyle(Color.hbMuted)
                            }
                            Spacer()
                            Text(health.latest(m.id).map { m.formatWithUnit($0.value) } ?? "—")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(health.latest(m.id) == nil ? Color.hbMuted : .primary)
                        }
                    }
                }
            }
        }
        .card()
    }
}

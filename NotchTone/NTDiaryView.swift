import SwiftUI

struct NTDiaryView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth

    @State private var loudness: Int = 5
    @State private var annoyance: Int = 5
    @State private var sleepQuality: Int = 5
    @State private var factors: Set<String> = []
    @State private var note: String = ""
    @State private var loaded: Bool = false
    @State private var savedFlash: Bool = false
    @State private var chartMetric: Int = 0
    @State private var showDeleteConfirm: Bool = false

    private var todayKey: Int { NTFormat.dayKey(Date()) }

    var body: some View {
        NTScreen(title: "Diary",
                 subtitle: "One entry a day. Rating once, at a consistent time, tells you far more than rating whenever the sound is at its worst.") {

            entryCard
            summaryCard
            historySection
            correlationLink
            sessionSection

            NTInlineDisclaimer(text: "Everything in the diary stays on this device. Patterns you find here are associations in your own log, not causes, and not a medical assessment.")
        }
        .onAppear(perform: loadToday)
        .alert(isPresented: $showDeleteConfirm) {
            Alert(title: Text("Delete today's entry?"),
                  message: Text("The ratings, tags and note for today will be removed. Earlier days are not affected."),
                  primaryButton: .destructive(Text("Delete")) {
                      store.deleteEntry(dayKey: todayKey)
                      resetFields()
                  },
                  secondaryButton: .cancel(Text("Keep")))
        }
    }

    // MARK: - Entry

    private var entryCard: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TODAY")
                            .font(NTTheme.mono(10, .semibold))
                            .foregroundColor(NTTheme.cyan)
                            .tracking(1.6)
                        Text(NTFormat.fullDate.string(from: Date()))
                            .font(NTTheme.rounded(18, .bold))
                            .foregroundColor(NTTheme.ink)
                    }
                    Spacer(minLength: 0)
                    if store.entry(for: todayKey) != nil {
                        HStack(spacing: 5) {
                            NTCheckGlyph(size: 14, color: NTTheme.seriesMask)
                            Text("Saved")
                                .font(NTTheme.mono(11))
                                .foregroundColor(NTTheme.seriesMask)
                        }
                    }
                }

                scaleBlock(metric: .loudness, value: $loudness)
                scaleBlock(metric: .annoyance, value: $annoyance)
                scaleBlock(metric: .sleep, value: $sleepQuality)

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT ELSE HAPPENED")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    factorGrid
                    if let f = factors.first, factors.count == 1,
                       let hint = NTFactors.all.first(where: { $0.id == f })?.hint {
                        Text(hint)
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Tap everything that applied today. Tags with fewer than five days of data are never turned into a number.")
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTE")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(NTTheme.panelHigh)
                        if note.isEmpty {
                            Text("Anything worth remembering about today")
                                .font(NTTheme.rounded(13))
                                .foregroundColor(NTTheme.inkFaint)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $note)
                            .font(NTTheme.rounded(13))
                            .foregroundColor(NTTheme.ink)
                            .accentColor(NTTheme.cyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    .frame(height: 46)
                }

                HStack(spacing: 10) {
                    Button(action: save) {
                        NTButtonLabel(title: savedFlash ? "Saved" : "Save today's entry",
                                      filled: true, tint: savedFlash ? NTTheme.seriesMask : NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if store.entry(for: todayKey) != nil {
                    Button(action: { showDeleteConfirm = true }) {
                        NTButtonLabel(title: "Delete today's entry", filled: false, tint: NTTheme.inkFaint, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func scaleBlock(metric: NTDiaryMetric, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(metric.longTitle)
                    .font(NTTheme.rounded(14, .medium))
                    .foregroundColor(NTTheme.ink)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(NTTheme.mono(16, .bold))
                    .foregroundColor(metric.tint)
            }
            NTScaleRow(value: value, tint: metric.tint,
                       lowLabel: metric.lowLabel, highLabel: metric.highLabel)
        }
    }

    private var factorGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 104), spacing: 7)]
        return LazyVGrid(columns: columns, spacing: 7) {
            ForEach(NTFactors.all) { factor in
                Button(action: {
                    if factors.contains(factor.id) { factors.remove(factor.id) }
                    else { factors.insert(factor.id) }
                }) {
                    Text(factor.title)
                        .font(NTTheme.rounded(12, .medium))
                        .foregroundColor(factors.contains(factor.id) ? NTTheme.deep : NTTheme.inkDim)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(factors.contains(factor.id) ? NTTheme.indigo : NTTheme.panelHigh)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func loadToday() {
        guard !loaded else { return }
        loaded = true
        if let e = store.entry(for: todayKey) {
            loudness = e.loudness
            annoyance = e.annoyance
            sleepQuality = e.sleepQuality
            factors = Set(e.factors)
            note = e.note
        }
    }

    private func resetFields() {
        loudness = 5
        annoyance = 5
        sleepQuality = 5
        factors = []
        note = ""
    }

    private func save() {
        var e = NTDiaryEntry(dayKey: todayKey)
        e.loudness = loudness
        e.annoyance = annoyance
        e.sleepQuality = sleepQuality
        e.factors = Array(factors).sorted()
        e.note = note
        store.upsert(e)
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { savedFlash = false }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "At a glance")
            HStack(spacing: 8) {
                NTStatTile(caption: "Entries",
                           value: "\(store.diary.count)",
                           detail: store.diary.count < 5 ? "Five days unlocks the correlation view" : "Enough to look for patterns",
                           tint: NTTheme.cyan)
                NTStatTile(caption: "Streak",
                           value: "\(store.diaryStreak)",
                           detail: store.diaryStreak == 1 ? "day in a row" : "days in a row",
                           tint: NTTheme.seriesMask)
            }
            HStack(spacing: 8) {
                NTStatTile(caption: "Loudness, 7 days",
                           value: store.recentMean(.loudness, days: 7).map { NTNum.oneDecimal($0) } ?? "—",
                           detail: trendDetail(.loudness),
                           tint: NTTheme.seriesPitch)
                NTStatTile(caption: "Listening",
                           value: NTFormat.durationWords(store.totalListeningSeconds),
                           detail: "\(store.sessions.count) logged session\(store.sessions.count == 1 ? "" : "s")",
                           tint: NTTheme.seriesLoud)
            }
        }
    }

    private func trendDetail(_ metric: NTDiaryMetric) -> String {
        guard let t = store.trend(metric, window: 7) else { return "Needs 14 days to compare" }
        if abs(t) < 0.15 { return "Level against the week before" }
        let better = metric.higherIsBetter ? t > 0 : t < 0
        return String(format: "%@%.1f against the week before · %@", t > 0 ? "+" : "", t, better ? "better" : "worse")
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "History",
                            caption: "The last thirty days you logged, with your factor tags marked underneath.")

            NTSegmented(options: NTDiaryMetric.allCases.map { $0.title }, index: $chartMetric)

            let metric = NTDiaryMetric(rawValue: chartMetric) ?? .loudness
            let entries = Array(store.diary.sorted { $0.dayKey < $1.dayKey }.suffix(30))

            NTPanel(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    if entries.isEmpty {
                        Text("No entries yet. Save today's ratings and the chart starts here.")
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 22)
                    } else {
                        NTLineChart(points: entries.enumerated().map { (i, e) in
                                        NTChartPoint(id: i,
                                                     label: NTFormat.dayKeyLabel(e.dayKey),
                                                     value: Double(metric.value(from: e)))
                                    },
                                    minValue: 0, maxValue: 10,
                                    tint: metric.tint, height: 150,
                                    valueFormatter: { String(format: "%.0f", $0) })

                        factorRibbon(entries)

                        Text(metric.higherIsBetter
                             ? "Higher is better on this measure."
                             : "Lower is better on this measure.")
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                    }
                }
            }
        }
    }

    private func factorRibbon(_ entries: [NTDiaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Canvas { ctx, size in
                let leftPad: CGFloat = 34
                let w = max(1, size.width - leftPad - 6)
                let n = max(1, entries.count)
                for (i, e) in entries.enumerated() {
                    let x = entries.count == 1 ? leftPad + w / 2
                                               : leftPad + w * CGFloat(i) / CGFloat(max(1, n - 1))
                    let count = min(4, e.factors.count)
                    for k in 0..<count {
                        let y = CGFloat(k) * 6 + 3
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y, width: 4, height: 4)),
                                 with: .color(NTTheme.indigo.opacity(0.9 - Double(k) * 0.15)))
                    }
                }
            }
            .frame(height: 27)
            Text("Each dot is one factor tag logged that day.")
                .font(NTTheme.rounded(10))
                .foregroundColor(NTTheme.inkFaint)
        }
    }

    // MARK: - Correlation link

    private var correlationLink: some View {
        NavigationLink(destination: NTCorrelationView().environmentObject(store)) {
            NTPanel(padding: 14) {
                HStack(alignment: .top, spacing: 12) {
                    NTBarsGlyph(size: 22, color: NTTheme.cyan, heights: [0.8, 0.35, 0.65, 0.5, 0.9])
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Correlation view")
                            .font(NTTheme.rounded(16, .semibold))
                            .foregroundColor(NTTheme.ink)
                        Text(store.diary.count >= 10
                             ? "Compare your ratings on days with each factor against days without, with the sample counts printed beside every number."
                             : "Needs a handful of entries before it can show anything. Keep logging and it fills in.")
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkDim)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    NTChevronGlyph(size: 16, color: NTTheme.cyan)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Sessions

    @ViewBuilder
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Session log",
                            caption: "What you listened to, for how long, and how that day's rating compared with your own average.")

            if store.sessions.isEmpty {
                NTEmptyState(title: "No sessions logged yet",
                             message: "Sessions of twenty seconds or more are recorded automatically when you stop playback on the Sound tab.")
            } else {
                NTPanel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(store.sessions.prefix(14).enumerated()), id: \.element.id) { pair in
                            sessionRow(pair.element)
                            if pair.offset < min(14, store.sessions.count) - 1 {
                                Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ log: NTSessionLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NTFormat.durationWords(log.seconds))
                    .font(NTTheme.mono(14, .semibold))
                    .foregroundColor(NTTheme.cyan)
                Text(NTFormat.clock.string(from: log.startedAt))
                    .font(NTTheme.mono(10))
                    .foregroundColor(NTTheme.inkFaint)
            }
            .frame(width: 66, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(log.summary)
                    .font(NTTheme.rounded(13))
                    .foregroundColor(NTTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(dayComparison(log.dayKey))
                    .font(NTTheme.rounded(11))
                    .foregroundColor(NTTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(NTFormat.dayKeyLabel(log.dayKey))
                .font(NTTheme.mono(10))
                .foregroundColor(NTTheme.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func dayComparison(_ dayKey: Int) -> String {
        guard let entry = store.entry(for: dayKey) else {
            return "No diary entry for that day."
        }
        let all = store.diary.map { Double($0.loudness) }
        guard all.count >= 3 else {
            return "Loudness logged that day: \(entry.loudness)."
        }
        let mean = NTNum.safeDiv(all.reduce(0, +), Double(all.count))
        let delta = Double(entry.loudness) - mean
        if abs(delta) < 0.5 {
            return String(format: "Loudness %d, about your average of %.1f.", entry.loudness, mean)
        }
        return String(format: "Loudness %d, %.1f %@ your average of %.1f.",
                      entry.loudness, abs(delta), delta < 0 ? "below" : "above", mean)
    }
}

// MARK: - Correlation view

struct NTCorrelationView: View {
    @EnvironmentObject private var store: NTStore
    @State private var metricIndex: Int = 0

    private var metric: NTDiaryMetric { NTDiaryMetric(rawValue: metricIndex) ?? .loudness }

    var body: some View {
        NTDetailScreen(title: "Correlation view",
                       subtitle: "Your ratings on days with each factor, against days without it.") {

            NTSafetyNote(text: "This is an association in your own log, not a cause. A factor and a rating moving together can happen for many reasons, including coincidence and the order you noticed things in.")

            NTSegmented(options: NTDiaryMetric.allCases.map { $0.title }, index: $metricIndex)

            NTPanel(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("READING THIS")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    Text("The upper bar is your mean " + metric.title.lowercased() + " on days you tagged the factor; the lower bar is days you did not. Sample counts are printed for both. Anything with fewer than five days on either side shows as not enough data rather than as a number.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if store.diary.count < 5 {
                NTEmptyState(title: "Not enough entries yet",
                             message: "The correlation view needs at least five days on each side of a comparison before it will print a number. Keep logging — it fills in on its own.")
            } else {
                listeningCard
                ForEach(store.factorStats(metric: metric)) { stat in
                    statCard(stat)
                }
            }

            NTInlineDisclaimer(text: "Notch Tone is not a medical device. Nothing on this screen is a diagnosis or an instruction, and no factor listed here is claimed to cause or relieve tinnitus.")
        }
    }

    private var listeningCard: some View {
        let stat = store.listeningComparison(metric: metric)
        return statCard(stat, tint: NTTheme.cyan,
                        footer: "Sessions of five minutes or more count as a listening day. This comparison cannot tell you whether listening helped: people also listen more on bad days.")
    }

    private func statCard(_ stat: NTStore.NTFactorStat,
                          tint: Color = NTTheme.indigo,
                          footer: String? = nil) -> some View {
        NTPanel(padding: 13) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(stat.title)
                        .font(NTTheme.rounded(15, .semibold))
                        .foregroundColor(NTTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if stat.hasEnoughData {
                        Text(differenceLabel(stat))
                            .font(NTTheme.mono(13, .semibold))
                            .foregroundColor(differenceTint(stat))
                    } else {
                        Text("not enough data")
                            .font(NTTheme.mono(11))
                            .foregroundColor(NTTheme.inkFaint)
                    }
                }

                if stat.hasEnoughData {
                    NTCompareBar(leftValue: stat.meanWith, rightValue: stat.meanWithout,
                                 maxValue: 10, leftTint: tint, rightTint: NTTheme.panelEdge)
                    HStack {
                        Text(String(format: "With: %.1f  (%d day%@)", stat.meanWith, stat.withCount,
                                    stat.withCount == 1 ? "" : "s"))
                            .font(NTTheme.mono(11))
                            .foregroundColor(tint)
                        Spacer()
                        Text(String(format: "Without: %.1f  (%d day%@)", stat.meanWithout, stat.withoutCount,
                                    stat.withoutCount == 1 ? "" : "s"))
                            .font(NTTheme.mono(11))
                            .foregroundColor(NTTheme.inkDim)
                    }
                } else {
                    Text("Logged on \(stat.withCount) day\(stat.withCount == 1 ? "" : "s"), not logged on \(stat.withoutCount). Five of each is the minimum before a number is worth printing.")
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let f = footer {
                    Text(f)
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func differenceLabel(_ stat: NTStore.NTFactorStat) -> String {
        String(format: "%@%.1f", stat.difference > 0 ? "+" : "", stat.difference)
    }

    private func differenceTint(_ stat: NTStore.NTFactorStat) -> Color {
        if abs(stat.difference) < 0.4 { return NTTheme.inkDim }
        let worse = metric.higherIsBetter ? stat.difference < 0 : stat.difference > 0
        return worse ? NTTheme.amber : NTTheme.seriesMask
    }
}

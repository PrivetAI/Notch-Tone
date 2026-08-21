import SwiftUI

struct NTMeasureView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Binding var selectedTab: Int

    @State private var historyMetric: Int = 0

    var body: some View {
        NTScreen(title: "Measure",
                 subtitle: "Four self-matching exercises. Each one produces a dated record you can compare against your own earlier attempts.") {

            NTSafetyNote(text: "This is a self-matching exercise, not an audiometric hearing test. It cannot measure hearing loss. Everything it produces is in the app's own relative units.")

            profileCard
            procedureList
            historySection
            recentRecords

            NTInlineDisclaimer(text: "Notch Tone is not a medical device. If your tinnitus is sudden, one-sided, pulsatile, or accompanied by hearing loss or dizziness, please see an audiologist or a doctor rather than relying on anything measured here.")
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    NTForkGlyph(size: 20, color: NTTheme.cyan)
                    Text("Your profile")
                        .font(NTTheme.rounded(18, .bold))
                        .foregroundColor(NTTheme.ink)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    NTStatTile(caption: "Pitch",
                               value: store.profile.hasPitch ? NTNum.hz(store.profile.matchedFrequency ?? 0) : "—",
                               detail: dateDetail(store.profile.matchedAt),
                               tint: NTTheme.seriesPitch)
                    NTStatTile(caption: "Loudness",
                               value: store.profile.loudnessDb.map { String(format: "%.0f", $0) } ?? "—",
                               detail: store.profile.loudnessDb == nil ? "Not matched" : "relative dB",
                               tint: NTTheme.seriesLoud)
                }
                HStack(spacing: 8) {
                    NTStatTile(caption: "Masking",
                               value: store.profile.maskingDb.map { String(format: "%.0f", $0) } ?? "—",
                               detail: store.profile.maskingDb == nil ? "Not measured" : store.profile.maskingColour.title + " noise",
                               tint: NTTheme.seriesMask)
                    NTStatTile(caption: "Self-check",
                               value: store.selfChecks.first.map { "\($0.total)/48" } ?? "—",
                               detail: dateDetail(store.selfChecks.first?.date),
                               tint: NTTheme.seriesScore)
                }

                if store.profile.hasPitch {
                    Button(action: { selectedTab = 0 }) {
                        NTButtonLabel(title: "Build a sound around this", filled: false,
                                      tint: NTTheme.cyan, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                NTInlineDisclaimer(text: "Loudness and masking figures are relative in-app decibels below the app's own reference level. They are not dB SL or dB HL, because a phone and headphones are not calibrated.")
            }
        }
    }

    private func dateDetail(_ date: Date?) -> String {
        guard let d = date else { return "Not measured" }
        return NTFormat.fullDate.string(from: d)
    }

    // MARK: - Procedures

    private var procedureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Procedures",
                            caption: "Each one explains itself before any sound plays. Use headphones in a quiet room, and start every exercise at a low level.")

            NavigationLink(destination: NTPitchMatchView().environmentObject(store).environmentObject(synth)) {
                procedureRow(number: 1,
                             title: "Pitch match",
                             detail: "Find the frequency closest to your tinnitus using a logarithmic dial or a two-alternative bracketing procedure, then check for octave confusion.",
                             tint: NTTheme.seriesPitch,
                             enabled: true)
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(destination: NTLoudnessMatchView().environmentObject(store).environmentObject(synth)) {
                procedureRow(number: 2,
                             title: "Loudness match",
                             detail: store.profile.hasPitch
                                ? "At " + NTNum.hz(store.profile.matchedFrequency ?? 0) + ", raise the tone in one-decibel steps until it is about as loud as your tinnitus."
                                : "Needs a matched pitch first. Run the pitch match, then come back.",
                             tint: NTTheme.seriesLoud,
                             enabled: store.profile.hasPitch)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!store.profile.hasPitch)

            NavigationLink(destination: NTMaskingLevelView().environmentObject(store).environmentObject(synth)) {
                procedureRow(number: 3,
                             title: "Minimum masking level",
                             detail: "Raise noise one decibel at a time until your tinnitus is just covered. Not being able to cover it comfortably is a valid result.",
                             tint: NTTheme.seriesMask,
                             enabled: true)
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(destination: NTSelfCheckView().environmentObject(store)) {
                procedureRow(number: 4,
                             title: "Severity self-check",
                             detail: "Twelve questions written for this app about sleep, concentration, mood, everyday life and coping. Not a clinical questionnaire and not a clinical score.",
                             tint: NTTheme.seriesScore,
                             enabled: true)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func procedureRow(number: Int, title: String, detail: String, tint: Color, enabled: Bool) -> some View {
        NTPanel(padding: 13, tint: enabled ? NTTheme.panelEdge : NTTheme.gridFaint) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(NTTheme.mono(14, .bold))
                    .foregroundColor(enabled ? NTTheme.deep : NTTheme.inkFaint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(enabled ? tint : NTTheme.panelHigh))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(NTTheme.rounded(16, .semibold))
                        .foregroundColor(enabled ? NTTheme.ink : NTTheme.inkFaint)
                    Text(detail)
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                NTChevronGlyph(size: 16, color: enabled ? NTTheme.cyan : NTTheme.gridFaint)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "History",
                            caption: "How each measurement has moved over time. Only your own earlier attempts are meaningful comparisons.")

            NTSegmented(options: ["Pitch", "Loudness", "Masking", "Check"], index: $historyMetric)

            NTPanel(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    let series = historySeries
                    NTLineChart(points: series.points,
                                minValue: series.minValue,
                                maxValue: series.maxValue,
                                tint: series.tint,
                                height: 150,
                                valueFormatter: series.formatter)
                    Text(series.caption)
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct HistorySeries {
        var points: [NTChartPoint]
        var minValue: Double
        var maxValue: Double
        var tint: Color
        var caption: String
        var formatter: (Double) -> String
    }

    private var historySeries: HistorySeries {
        switch historyMetric {
        case 0:
            let recs = Array(store.pitchRecords.prefix(30)).reversed()
            let pts = recs.enumerated().map { (i, r) in
                NTChartPoint(id: i, label: NTFormat.dayLabel.string(from: r.date), value: log2(max(100, r.frequency)))
            }
            let values = pts.map { $0.value }
            let lo = (values.min() ?? 10) - 0.6
            let hi = (values.max() ?? 12) + 0.6
            return HistorySeries(points: pts, minValue: lo, maxValue: hi, tint: NTTheme.seriesPitch,
                                 caption: pts.isEmpty ? "No pitch matches recorded yet." :
                                    "Plotted on a logarithmic axis, so one octave is always the same distance. \(pts.count) match\(pts.count == 1 ? "" : "es") recorded.",
                                 formatter: { v in NTNum.hzShort(pow(2.0, v)) })
        case 1:
            let recs = Array(store.loudnessRecords.prefix(30)).reversed()
            let pts = recs.enumerated().map { (i, r) in
                NTChartPoint(id: i, label: NTFormat.dayLabel.string(from: r.date), value: r.relativeDb)
            }
            return HistorySeries(points: pts, minValue: -60, maxValue: 0, tint: NTTheme.seriesLoud,
                                 caption: pts.isEmpty ? "No loudness matches recorded yet." :
                                    "Relative in-app decibels below the app's reference level. Higher on the chart means you needed a louder tone to match.",
                                 formatter: { v in String(format: "%.0f", v) })
        case 2:
            let recs = Array(store.maskingRecords.prefix(30)).reversed().filter { !$0.notCovered }
            let pts = recs.enumerated().map { (i, r) in
                NTChartPoint(id: i, label: NTFormat.dayLabel.string(from: r.date), value: r.relativeDb)
            }
            return HistorySeries(points: pts, minValue: -60, maxValue: 0, tint: NTTheme.seriesMask,
                                 caption: pts.isEmpty ? "No masking levels recorded yet." :
                                    "Lower on the chart means less noise was needed to cover it, which usually makes sound easier to use.",
                                 formatter: { v in String(format: "%.0f", v) })
        default:
            let recs = Array(store.selfChecks.prefix(30)).reversed()
            let pts = recs.enumerated().map { (i, r) in
                NTChartPoint(id: i, label: NTFormat.dayLabel.string(from: r.date), value: Double(r.total))
            }
            return HistorySeries(points: pts, minValue: 0, maxValue: 48, tint: NTTheme.seriesScore,
                                 caption: pts.isEmpty ? "No self-checks completed yet." :
                                    "Out of 48. Lower means the sound is taking less from your days. This is not a clinical score.",
                                 formatter: { v in String(format: "%.0f", v) })
        }
    }

    // MARK: - Recent records

    @ViewBuilder
    private var recentRecords: some View {
        let rows = recentRows()
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                NTSectionHeader(title: "Recent records")
                NTPanel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(0..<rows.count, id: \.self) { i in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(rows[i].tint)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rows[i].title)
                                        .font(NTTheme.rounded(13, .medium))
                                        .foregroundColor(NTTheme.ink)
                                    Text(rows[i].detail)
                                        .font(NTTheme.rounded(11))
                                        .foregroundColor(NTTheme.inkFaint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Text(NTFormat.dayLabel.string(from: rows[i].date))
                                    .font(NTTheme.mono(10))
                                    .foregroundColor(NTTheme.inkFaint)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            if i < rows.count - 1 {
                                Rectangle().fill(NTTheme.gridFaint).frame(height: 1)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct RecentRow {
        let date: Date
        let title: String
        let detail: String
        let tint: Color
    }

    private func recentRows() -> [RecentRow] {
        var rows: [RecentRow] = []
        for r in store.pitchRecords.prefix(8) {
            rows.append(RecentRow(date: r.date,
                                  title: "Pitch match · " + NTNum.hz(r.frequency),
                                  detail: (r.method == "bracket" ? "Bracketing, \(r.rounds) rounds" : "Free sweep") +
                                          (r.octaveChecked ? " · octave checked" : "") + " · " + r.ear.title,
                                  tint: NTTheme.seriesPitch))
        }
        for r in store.loudnessRecords.prefix(8) {
            rows.append(RecentRow(date: r.date,
                                  title: String(format: "Loudness · %.0f relative dB", r.relativeDb),
                                  detail: "At " + NTNum.hz(r.frequency) + " · " + r.ear.title,
                                  tint: NTTheme.seriesLoud))
        }
        for r in store.maskingRecords.prefix(8) {
            rows.append(RecentRow(date: r.date,
                                  title: r.notCovered ? "Masking · not covered comfortably"
                                                      : String(format: "Masking · %.0f relative dB", r.relativeDb),
                                  detail: r.colour.title + " noise",
                                  tint: NTTheme.seriesMask))
        }
        for r in store.selfChecks.prefix(8) {
            rows.append(RecentRow(date: r.date,
                                  title: "Self-check · \(r.total)/48",
                                  detail: NTSelfCheck.band(for: r.total).title,
                                  tint: NTTheme.seriesScore))
        }
        return Array(rows.sorted { $0.date > $1.date }.prefix(12))
    }
}

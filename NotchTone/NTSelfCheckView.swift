import SwiftUI

struct NTSelfCheckView: View {
    @EnvironmentObject private var store: NTStore
    @Environment(\.presentationMode) private var presentationMode

    private enum Stage { case intro, items, result }

    @State private var stage: Stage = .intro
    @State private var raw: [Int] = Array(repeating: -1, count: NTSelfCheck.items.count)
    @State private var resultRecord: NTSelfCheckRecord? = nil

    var body: some View {
        NTDetailScreen(title: "Severity self-check",
                       subtitle: "Twelve questions written for this app about how much of your life the sound is taking.") {
            switch stage {
            case .intro: introSection
            case .items: itemsSection
            case .result: resultSection
            }
        }
    }

    // MARK: Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 11) {
                    Text("What this is")
                        .font(NTTheme.rounded(17, .bold))
                        .foregroundColor(NTTheme.ink)
                    para("Twelve statements, each answered on a five-point scale from never to almost always, covering sleep, concentration, mood, everyday life and how well you are coping. The total runs from 0 to 48.")
                    para("These questions were written for Notch Tone. They are not any published questionnaire, they were not validated in a clinic, and the total is not a clinical score. What the number is good for is watching your own trend across weeks and months.")
                    para("Answer for roughly the past two weeks, and answer quickly — first reactions are usually more honest than considered ones.")

                    NTSafetyNote(text: "This is a self-check, not a diagnosis and not a clinical assessment. Nothing here can tell you what is causing your tinnitus or what to do about it.")
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The five themes")
                        .font(NTTheme.rounded(16, .semibold))
                        .foregroundColor(NTTheme.ink)
                    ForEach(NTCheckTheme.allCases) { theme in
                        HStack(spacing: 10) {
                            Circle().fill(theme.tint).frame(width: 8, height: 8)
                            Text(theme.title)
                                .font(NTTheme.rounded(13, .medium))
                                .foregroundColor(NTTheme.ink)
                            Spacer(minLength: 0)
                            Text("\(NTSelfCheck.items.filter { $0.theme == theme }.count) items")
                                .font(NTTheme.mono(11))
                                .foregroundColor(NTTheme.inkFaint)
                        }
                    }

                    Button(action: {
                        raw = Array(repeating: -1, count: NTSelfCheck.items.count)
                        stage = .items
                    }) {
                        NTButtonLabel(title: "Start the self-check", filled: true, tint: NTTheme.seriesScore)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if let last = store.selfChecks.first {
                        Text("Last completed " + NTFormat.fullDate.string(from: last.date) +
                             " · \(last.total) out of 48.")
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !store.selfChecks.isEmpty {
                previousResults
            }
        }
    }

    private var previousResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Earlier results")
            NTPanel(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(store.selfChecks.prefix(10).enumerated()), id: \.element.id) { pair in
                        let rec = pair.element
                        HStack(spacing: 12) {
                            Text("\(rec.total)")
                                .font(NTTheme.mono(17, .bold))
                                .foregroundColor(NTSelfCheck.band(for: rec.total).tint)
                                .frame(width: 38, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NTSelfCheck.band(for: rec.total).title)
                                    .font(NTTheme.rounded(13, .medium))
                                    .foregroundColor(NTTheme.ink)
                                Text(NTFormat.fullDate.string(from: rec.date))
                                    .font(NTTheme.mono(10))
                                    .foregroundColor(NTTheme.inkFaint)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if pair.offset < min(10, store.selfChecks.count) - 1 {
                            Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }

    // MARK: Items

    private var answered: Int { raw.filter { $0 >= 0 }.count }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(answered) of \(NTSelfCheck.items.count) answered")
                            .font(NTTheme.mono(12, .semibold))
                            .foregroundColor(NTTheme.ink)
                        Spacer()
                        Text("Past two weeks")
                            .font(NTTheme.mono(10))
                            .foregroundColor(NTTheme.inkFaint)
                    }
                    GeometryReader { geo in
                        let frac = NTNum.clampF(CGFloat(NTNum.safeDiv(Double(answered), Double(NTSelfCheck.items.count))), 0, 1)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(NTTheme.panelHigh)
                            RoundedRectangle(cornerRadius: 3).fill(NTTheme.seriesScore)
                                .frame(width: max(3, geo.size.width * frac))
                        }
                    }
                    .frame(height: 6)
                }
            }

            ForEach(Array(NTSelfCheck.items.enumerated()), id: \.element.id) { pair in
                itemCard(index: pair.offset, item: pair.element)
            }

            Button(action: finish) {
                NTButtonLabel(title: answered == NTSelfCheck.items.count ? "See the result"
                                                                        : "Answer all twelve to continue",
                              filled: answered == NTSelfCheck.items.count,
                              tint: answered == NTSelfCheck.items.count ? NTTheme.seriesScore : NTTheme.inkFaint)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(answered < NTSelfCheck.items.count)

            Button(action: { stage = .intro }) {
                NTButtonLabel(title: "Cancel", filled: false, tint: NTTheme.inkDim, compact: true)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func itemCard(index: Int, item: NTCheckItem) -> some View {
        NTPanel(padding: 13) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(NTTheme.mono(11, .bold))
                        .foregroundColor(NTTheme.deep)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(item.theme.tint))
                    Text(item.text)
                        .font(NTTheme.rounded(14))
                        .foregroundColor(NTTheme.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 5) {
                    ForEach(0..<NTSelfCheck.answerLabels.count, id: \.self) { a in
                        Button(action: { raw[index] = a }) {
                            HStack(spacing: 10) {
                                NTSelectDot(size: 17, selected: raw[index] == a, tint: item.theme.tint)
                                Text(NTSelfCheck.answerLabels[a])
                                    .font(NTTheme.rounded(13))
                                    .foregroundColor(raw[index] == a ? NTTheme.ink : NTTheme.inkDim)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(raw[index] == a ? NTTheme.panelHigh : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func finish() {
        guard answered == NTSelfCheck.items.count else { return }
        var scored: [Int] = []
        for i in 0..<NTSelfCheck.items.count {
            scored.append(NTSelfCheck.score(itemIndex: i, rawAnswer: raw[i]))
        }
        let record = NTSelfCheckRecord(answers: scored)
        resultRecord = record
        stage = .result
    }

    // MARK: Result

    @ViewBuilder
    private var resultSection: some View {
        if let record = resultRecord {
            let band = NTSelfCheck.band(for: record.total)
            VStack(alignment: .leading, spacing: 14) {
                NTPanel(tint: band.tint.opacity(0.6)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELF-CHECK TOTAL")
                            .font(NTTheme.mono(10, .semibold))
                            .foregroundColor(band.tint)
                            .tracking(1.6)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(record.total)")
                                .font(NTTheme.mono(44, .bold))
                                .foregroundColor(NTTheme.ink)
                            Text("/ 48")
                                .font(NTTheme.mono(17))
                                .foregroundColor(NTTheme.inkFaint)
                        }
                        Text(band.title)
                            .font(NTTheme.rounded(19, .bold))
                            .foregroundColor(band.tint)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(band.summary)
                            .font(NTTheme.rounded(13))
                            .foregroundColor(NTTheme.inkDim)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        bandScale(record.total)

                        Text(band.suggestion)
                            .font(NTTheme.rounded(13))
                            .foregroundColor(NTTheme.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        NTInlineDisclaimer(text: "This is a self-check written for this app. It is not a clinical score, it has not been validated, and it cannot diagnose anything.")
                    }
                }

                NTPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Where the score came from")
                            .font(NTTheme.rounded(16, .semibold))
                            .foregroundColor(NTTheme.ink)
                        NTThemeBars(record: record)
                        Text("A theme carrying most of the total is usually the most useful place to start. Sleep in particular tends to improve other themes when it improves.")
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let previous = store.selfChecks.first {
                    NTPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compared with last time")
                                .font(NTTheme.rounded(16, .semibold))
                                .foregroundColor(NTTheme.ink)
                            let delta = record.total - previous.total
                            Text(delta == 0 ? "Unchanged from \(previous.total) on " + NTFormat.fullDate.string(from: previous.date)
                                            : String(format: "%@%d from %d on ", delta > 0 ? "+" : "", delta, previous.total)
                                              + NTFormat.fullDate.string(from: previous.date))
                                .font(NTTheme.mono(14, .semibold))
                                .foregroundColor(delta > 0 ? NTTheme.amber : (delta < 0 ? NTTheme.seriesMask : NTTheme.inkDim))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("A single comparison says very little. Several checks a few weeks apart say a great deal more.")
                                .font(NTTheme.rounded(11))
                                .foregroundColor(NTTheme.inkFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Button(action: {
                    store.recordSelfCheck(record)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    NTButtonLabel(title: "Save this result", filled: true, tint: NTTheme.seriesScore)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { stage = .items }) {
                    NTButtonLabel(title: "Go back and change answers", filled: false, tint: NTTheme.inkDim, compact: true)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } else {
            NTEmptyState(title: "Nothing to show",
                         message: "The self-check has not been completed in this session.")
        }
    }

    private func bandScale(_ total: Int) -> some View {
        Canvas { ctx, size in
            let w = size.width, h: CGFloat = 10
            let y = (size.height - h) / 2
            var x: CGFloat = 0
            for b in NTSelfCheck.bands {
                let span = CGFloat(b.upper - b.lower + 1) / CGFloat(NTSelfCheck.maximumScore + 1)
                let bw = w * span
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: max(2, bw - 2), height: h), cornerRadius: 3),
                         with: .color(b.tint.opacity(0.45)))
                x += bw
            }
            let px = w * CGFloat(NTNum.clamp(Double(total), 0, 48) / 48.0)
            var marker = Path()
            marker.move(to: CGPoint(x: px, y: y - 6))
            marker.addLine(to: CGPoint(x: px, y: y + h + 6))
            ctx.stroke(marker, with: .color(NTTheme.ink), lineWidth: 2)
        }
        .frame(height: 26)
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(13))
            .foregroundColor(NTTheme.inkDim)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

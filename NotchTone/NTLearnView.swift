import SwiftUI

struct NTLearnView: View {
    @EnvironmentObject private var store: NTStore
    @State private var filter: Int = 0
    /// The filtered list is held as a snapshot rather than recomputed on every store
    /// change. Marking a card read, or unsaving it from inside its own detail, must not
    /// delete the row whose NavigationLink pushed that detail — under iOS 15 destroying
    /// the link pops the screen out from under the reader mid-tap.
    @State private var visibleCards: [NTLearnCard] = NTLearn.all

    private func filteredCards() -> [NTLearnCard] {
        switch filter {
        case 1: return NTLearn.all.filter { store.bookmarkedCardIDs.contains($0.id) }
        case 2: return NTLearn.all.filter { !store.readCardIDs.contains($0.id) }
        default: return NTLearn.all
        }
    }

    var body: some View {
        NTScreen(title: "Learn",
                 subtitle: "\(NTLearn.all.count) reference cards, written for this app in plain language, with cautious claims and no product pitches.") {

            urgentBanner
            progressCard

            NTSegmented(options: ["All", "Saved", "Unread"], index: $filter)

            if visibleCards.isEmpty {
                NTEmptyState(title: filter == 1 ? "Nothing saved yet" : "You have read everything",
                             message: filter == 1
                                ? "Open any card and use the save control to keep it here for later."
                                : "Every card in the library has been opened at least once. The Saved filter keeps the ones you want to come back to.")
            } else {
                ForEach(NTLearn.groups) { group in
                    let cards = visibleCards.filter { $0.groupID == group.id }
                    if !cards.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            NTSectionHeader(title: group.title, caption: group.caption)
                            ForEach(cards) { card in
                                cardRow(card)
                            }
                        }
                    }
                }
            }

            NTInlineDisclaimer(text: "This library is general information, not medical advice, and Notch Tone is not a medical device. For anything about your own ears, see an audiologist or a doctor.")
        }
        .onAppear { visibleCards = filteredCards() }
        .onChange(of: filter) { _ in visibleCards = filteredCards() }
    }

    private var urgentBanner: some View {
        Group {
            if let card = NTLearn.urgentCard {
                NavigationLink(destination: NTLearnCardView(card: card).environmentObject(store)) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            NTWarnGlyph(size: 20, color: NTTheme.amber)
                            Text("Read this one first")
                                .font(NTTheme.rounded(16, .bold))
                                .foregroundColor(NTTheme.amber)
                            Spacer(minLength: 0)
                            NTChevronGlyph(size: 15, color: NTTheme.amber)
                        }
                        Text(card.title)
                            .font(NTTheme.rounded(15, .semibold))
                            .foregroundColor(NTTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Sudden onset, one ear only, pulsing with your heartbeat, hearing loss, dizziness, or anything neurological — these deserve a professional's attention soon rather than eventually.")
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkDim)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: NTTheme.corner, style: .continuous)
                                    .fill(NTTheme.amberDeep.opacity(0.22)))
                    .overlay(RoundedRectangle(cornerRadius: NTTheme.corner, style: .continuous)
                                .stroke(NTTheme.amber.opacity(0.45), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var progressCard: some View {
        let read = store.readCardIDs.intersection(Set(NTLearn.all.map { $0.id })).count
        let total = NTLearn.all.count
        return NTPanel(padding: 13) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("READING PROGRESS")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    Spacer()
                    Text("\(read) of \(total)")
                        .font(NTTheme.mono(13, .semibold))
                        .foregroundColor(NTTheme.cyan)
                }
                GeometryReader { geo in
                    let frac = NTNum.clampF(CGFloat(NTNum.safeDiv(Double(read), Double(total))), 0, 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(NTTheme.panelHigh)
                        RoundedRectangle(cornerRadius: 3).fill(NTTheme.cyan)
                            .frame(width: max(3, geo.size.width * frac))
                    }
                }
                .frame(height: 6)
                Text(store.bookmarkedCardIDs.isEmpty
                     ? "Cards you open are marked as read. Save the ones you want to come back to."
                     : "\(store.bookmarkedCardIDs.count) card\(store.bookmarkedCardIDs.count == 1 ? "" : "s") saved.")
                    .font(NTTheme.rounded(11))
                    .foregroundColor(NTTheme.inkFaint)
            }
        }
    }

    private func cardRow(_ card: NTLearnCard) -> some View {
        NavigationLink(destination: NTLearnCardView(card: card).environmentObject(store)) {
            NTPanel(padding: 13, tint: card.urgent ? NTTheme.amber.opacity(0.45) : NTTheme.panelEdge) {
                HStack(alignment: .top, spacing: 11) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(card.title)
                                .font(NTTheme.rounded(15, .semibold))
                                .foregroundColor(NTTheme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if store.bookmarkedCardIDs.contains(card.id) {
                                NTCheckGlyph(size: 13, color: NTTheme.indigo)
                            }
                        }
                        Text(card.summary)
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkDim)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Text("\(card.minutes) min read")
                                .font(NTTheme.mono(10))
                                .foregroundColor(NTTheme.inkFaint)
                            if store.readCardIDs.contains(card.id) {
                                Text("read")
                                    .font(NTTheme.mono(10))
                                    .foregroundColor(NTTheme.seriesMask)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    NTChevronGlyph(size: 15, color: NTTheme.cyan)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card detail

struct NTLearnCardView: View {
    let card: NTLearnCard
    @EnvironmentObject private var store: NTStore

    var body: some View {
        NTDetailScreen(title: card.title, subtitle: card.summary) {
            if card.urgent {
                NTSafetyNote(text: "This card is about when to involve a professional. It is not a diagnosis and it does not mean anything is wrong — it means someone qualified should look.")
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<card.blocks.count, id: \.self) { i in
                    blockView(card.blocks[i])
                }
            }

            Button(action: {
                if store.bookmarkedCardIDs.contains(card.id) {
                    store.bookmarkedCardIDs.remove(card.id)
                } else {
                    store.bookmarkedCardIDs.insert(card.id)
                }
            }) {
                NTButtonLabel(title: store.bookmarkedCardIDs.contains(card.id) ? "Remove from saved" : "Save this card",
                              filled: false,
                              tint: store.bookmarkedCardIDs.contains(card.id) ? NTTheme.inkDim : NTTheme.indigo)
            }
            .buttonStyle(PlainButtonStyle())

            NTInlineDisclaimer(text: "General information only. Notch Tone is not a medical device and does not provide medical advice.")
        }
        .onDisappear {
            // Marked on the way out, not on the way in: "read" then means actually
            // looked at, and the list behind this screen cannot lose the row that
            // pushed it while the reader is still standing on it.
            store.readCardIDs.insert(card.id)
        }
    }

    @ViewBuilder
    private func blockView(_ block: NTLearnBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(NTTheme.rounded(14))
                .foregroundColor(NTTheme.inkDim)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<items.count, id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(NTTheme.cyan)
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(items[i])
                            .font(NTTheme.rounded(14))
                            .foregroundColor(NTTheme.inkDim)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .callout(let text):
            NTSafetyNote(text: text)

        case .pairs(let pairs):
            NTPanel(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(0..<pairs.count, id: \.self) { i in
                        HStack(alignment: .top, spacing: 12) {
                            Text(pairs[i].left)
                                .font(NTTheme.mono(12, .semibold))
                                .foregroundColor(NTTheme.cyan)
                                .frame(width: 84, alignment: .leading)
                            Text(pairs[i].right)
                                .font(NTTheme.rounded(13))
                                .foregroundColor(NTTheme.inkDim)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if i < pairs.count - 1 {
                            Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                        }
                    }
                }
            }

        case .exposureTable:
            exposureTable
        }
    }

    private var exposureTable: some View {
        NTPanel(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("SOURCE")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    Spacer(minLength: 0)
                    Text("LEVEL")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                        .frame(width: 52, alignment: .trailing)
                    Text("SAFE FOR")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                        .frame(width: 86, alignment: .trailing)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(NTTheme.panelHigh)

                ForEach(NTLearn.exposureRows) { row in
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(NTLearn.severityColor(row.severity))
                            .frame(width: 3, height: 26)
                            .cornerRadius(1.5)
                        Text(row.source)
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text(row.level)
                            .font(NTTheme.mono(11, .semibold))
                            .foregroundColor(NTLearn.severityColor(row.severity))
                            .frame(width: 52, alignment: .trailing)
                        Text(row.safeTime)
                            .font(NTTheme.mono(10))
                            .foregroundColor(NTTheme.inkDim)
                            .frame(width: 86, alignment: .trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)
                }

                Text("Commonly cited approximations for orientation only. Real levels vary a great deal with distance and setting, and this is general guidance rather than a personal instruction.")
                    .font(NTTheme.rounded(11))
                    .foregroundColor(NTTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
            }
        }
    }
}

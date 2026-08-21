import SwiftUI

/// The first-run explainer. Re-openable at any time from Settings.
struct NTOnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var store: NTStore
    @State private var page: Int = 0

    private let pageCount = 6

    var body: some View {
        ZStack {
            LinearGradient(colors: [NTTheme.deep, NTTheme.panel],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        pageContent
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? NTTheme.cyan : NTTheme.panelEdge)
                                .frame(width: i == page ? 18 : 6, height: 6)
                        }
                    }

                    HStack(spacing: 12) {
                        if page > 0 {
                            Button(action: { page -= 1 }) {
                                NTButtonLabel(title: "Back", filled: false, tint: NTTheme.inkDim)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Button(action: advance) {
                            NTButtonLabel(title: page == pageCount - 1 ? "Start" : "Continue",
                                          filled: true, tint: NTTheme.cyan)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 22)
                .background(NTTheme.panel.opacity(0.96).edgesIgnoringSafeArea(.bottom))
            }
        }
    }

    private func advance() {
        if page < pageCount - 1 {
            page += 1
        } else {
            store.settings.hasSeenOnboarding = true
            isPresented = false
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            headline("Notch Tone")
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let bars = 30
                let gap: CGFloat = 4
                let bw = (w - gap * CGFloat(bars - 1)) / CGFloat(bars)
                for i in 0..<bars {
                    let t = Double(i) / Double(bars - 1)
                    let d = abs(t - 0.5)
                    let gate = d < 0.10 ? 0.10 : 1.0
                    let wave = 0.4 + 0.5 * abs(sin(t * 3.1))
                    let barH = CGFloat(wave * gate) * h
                    let x = CGFloat(i) * (bw + gap)
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: (h - barH) / 2, width: bw, height: max(2, barH)),
                                  cornerRadius: bw / 2),
                             with: .color(d < 0.10 ? NTTheme.amber.opacity(0.6) : NTTheme.cyan.opacity(0.65)))
                }
            }
            .frame(height: 90)
            para("This app does two things. It helps you describe your own tinnitus — its pitch, how loud it seems, and how much noise it takes to cover it. Then it generates sound built around those numbers.")
            para("The signature sound is notched noise: broadband noise with a band removed exactly where your tinnitus sits. That gap is the notch, and it is why the app is called what it is.")
            para("Every sound here is synthesised one sample at a time by code. There is not a single audio file in the app.")

        case 1:
            headline("What this app is not")
            NTSafetyNote(text: "Notch Tone is not a medical device. It does not diagnose, treat or cure anything, and nothing in it is medical advice.")
            para("The pitch match is a self-matching exercise, not an audiometric hearing test. A phone and an arbitrary pair of headphones have no calibrated output level, so nothing measured here can tell you anything about hearing loss.")
            para("Every number the app produces is in its own relative units and is useful only for comparison against your own earlier attempts.")
            para("If your tinnitus started suddenly, is in one ear only, pulses with your heartbeat, or comes with hearing loss or dizziness, please see an audiologist or a doctor. That list is in the Learn tab as its own card.")

        case 2:
            headline("Volume safety comes first")
            NTSafetyNote(text: "Sudden loud sound can make tinnitus worse. Start every session quiet, and never raise the level past comfortable.")
            bullet("Set the level in a quiet room, before you need it, and leave it there.")
            bullet("Aim for a level where the sound is comfortably present, not one that competes with your tinnitus for prominence.")
            bullet("Do not use sound to bury your tinnitus at high volume. Partial masking at a low level is what most structured approaches aim for.")
            bullet("Use the sleep timer so your ears get quiet hours.")
            para("The app caps its own output conservatively, and you can lower that cap further in Settings. Every sound fades in over about three tenths of a second so nothing ever starts with a click or a blast.")

        case 3:
            headline("Three self-matching exercises")
            numbered(1, "Pitch match", "A logarithmic dial from 250 Hz to 12 kHz, plus a two-alternative bracketing procedure that halves the search each round. Octave confusion is common, so the app offers an explicit octave check afterwards.")
            numbered(2, "Loudness match", "At your matched frequency, raise the tone in one-decibel steps until it is about as loud as your tinnitus. Recorded in relative in-app decibels.")
            numbered(3, "Minimum masking level", "Raise noise until your tinnitus is just covered. If it is not covered at a comfortable level, record that instead — it is a valid result.")
            para("There is also a twelve-item self-check written for this app, covering sleep, concentration, mood, everyday life and coping. It is not a clinical questionnaire and gives no clinical score.")

        case 4:
            headline("Building a sound")
            para("The Sound tab starts from your profile. If you have matched a pitch, the top card is a notched preset centred on it, one tap from playing.")
            bullet("Stack up to three generators, each with its own parameters and level.")
            bullet("Eight authored presets ship with the app; save your own at any time.")
            bullet("The drawn spectrum is computed from the same filter coefficients the audio engine runs, so the gap you see is the gap you hear.")
            bullet("A sleep timer from fifteen to ninety minutes fades out slowly over the last minute rather than cutting off.")

        case 5:
            headline("Keeping a record")
            para("The Diary tab takes one entry a day: perceived loudness, how much it bothered you, and how you slept, plus factor tags such as loud noise, poor sleep, caffeine or a quiet day.")
            para("The correlation view compares your ratings on days with each factor against days without, prints the sample counts beside every number, and refuses to show a figure at all below five samples. An association in your own log is not a cause, and the app says so every time.")
            NTSafetyNote(text: "Everything stays on this device. Nothing is uploaded, and there are no accounts.")

        default:
            EmptyView()
        }
    }

    private func headline(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(27, .bold))
            .foregroundColor(NTTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(14))
            .foregroundColor(NTTheme.inkDim)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(NTTheme.cyan)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(NTTheme.rounded(14))
                .foregroundColor(NTTheme.inkDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func numbered(_ n: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(NTTheme.mono(13, .bold))
                .foregroundColor(NTTheme.deep)
                .frame(width: 24, height: 24)
                .background(Circle().fill(NTTheme.cyan))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NTTheme.rounded(15, .semibold))
                    .foregroundColor(NTTheme.ink)
                Text(text)
                    .font(NTTheme.rounded(13))
                    .foregroundColor(NTTheme.inkDim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The warning shown before the very first sound plays, and re-shown from Settings.
struct NTVolumeWarningView: View {
    @Binding var isPresented: Bool
    var onAccept: () -> Void
    var showAcceptButton: Bool = true

    var body: some View {
        ZStack {
            NTTheme.deep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        NTWarnGlyph(size: 28, color: NTTheme.amber)
                        Text("Before you play anything")
                            .font(NTTheme.rounded(23, .bold))
                            .foregroundColor(NTTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NTSafetyNote(text: "Sudden or sustained loud sound can make tinnitus worse, sometimes lastingly. This matters more than anything else in the app.")

                    VStack(alignment: .leading, spacing: 12) {
                        rule("Start at the lowest level you can hear.", "Raise it slowly, in a quiet room, and stop as soon as it is comfortably present.")
                        rule("Never raise sound above a comfortable level.", "If you find yourself turning it up to keep an effect, turn it down instead and take a break.")
                        rule("Do not mask at high volume.", "Burying your tinnitus under loud noise gives short relief at a real cost. A quiet bed that leaves it faintly audible is the safer and usually more effective choice.")
                        rule("Use the timer.", "Your ears benefit from quiet hours. The sleep timer fades out slowly rather than cutting off.")
                        rule("Take the phone's volume seriously.", "The app caps its own output, but your device volume and your headphones still set the final level.")
                    }

                    NTInlineDisclaimer(text: "Notch Tone is not a medical device and does not diagnose, treat or cure anything. If your tinnitus is sudden, one-sided, pulsatile, or comes with hearing loss or dizziness, see an audiologist or a doctor.")

                    if showAcceptButton {
                        Button(action: {
                            onAccept()
                            isPresented = false
                        }) {
                            NTButtonLabel(title: "I understand — start quiet", filled: true, tint: NTTheme.amber)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    } else {
                        Button(action: { isPresented = false }) {
                            NTButtonLabel(title: "Close", filled: false, tint: NTTheme.cyan)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(NTTheme.rounded(15, .semibold))
                .foregroundColor(NTTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(NTTheme.rounded(13))
                .foregroundColor(NTTheme.inkDim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI

// MARK: - Shared pieces

/// The ear selector used by every procedure.
struct NTEarPicker: View {
    @Binding var ear: NTEar
    var onChange: ((NTEar) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("PRESENT TO")
                .font(NTTheme.mono(9, .semibold))
                .foregroundColor(NTTheme.inkFaint)
                .tracking(1.0)
            HStack(spacing: 6) {
                ForEach(NTEar.allCases, id: \.rawValue) { e in
                    Button(action: {
                        ear = e
                        onChange?(e)
                    }) {
                        Text(e.title)
                            .font(NTTheme.mono(12, .medium))
                            .foregroundColor(ear == e ? NTTheme.deep : NTTheme.inkDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(ear == e ? NTTheme.cyan : NTTheme.panelHigh)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Text("Left and right require headphones. Without them the phone plays to both ears whatever is chosen here.")
                .font(NTTheme.rounded(10))
                .foregroundColor(NTTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The big play/stop control used inside the procedures.
struct NTAuditionButton: View {
    let playing: Bool
    let title: String
    let action: () -> Void
    var tint: Color = NTTheme.cyan

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if playing {
                    NTStopGlyph(size: 16, color: NTTheme.deep)
                } else {
                    NTPlayGlyph(size: 16, color: NTTheme.deep)
                }
                Text(playing ? "Stop" : title)
                    .font(NTTheme.rounded(14, .semibold))
                    .foregroundColor(NTTheme.deep)
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// The level control shared by all three procedures, expressed as attenuation
/// below the app's own reference level.
struct NTLevelLadder: View {
    @Binding var attenuation: Double
    let onChange: (Double) -> Void
    var floorDb: Double = -75
    var ceilingDb: Double = -6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NTLadderStepper(value: attenuation,
                            unit: "dB",
                            stepLabel: "relative to the app's reference",
                            onDown: { step(-1) },
                            onUp: { step(1) },
                            atCeiling: attenuation >= ceilingDb - 6)

            NTSlider(value: Binding(get: { attenuation },
                                    set: { v in
                                        attenuation = (v).rounded()
                                        onChange(attenuation)
                                    }),
                     range: floorDb...ceilingDb, ticks: 8, tint: NTTheme.cyan)

            if attenuation >= ceilingDb - 6 {
                NTSafetyNote(text: "You are near the app's output ceiling. If you still need more, the level is already higher than is worth using — stop here and record what you have.")
            }
        }
    }

    private func step(_ delta: Double) {
        attenuation = NTNum.clamp(attenuation + delta, floorDb, ceilingDb)
        onChange(attenuation)
    }
}

// MARK: - 1. Pitch match

struct NTPitchMatchView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Environment(\.presentationMode) private var presentationMode

    private enum Stage {
        case intro, free, bracket, octave, result
    }

    @State private var stage: Stage = .intro
    @State private var mode: Int = 1              // 0 = free sweep, 1 = bracketing
    @State private var frequency: Double = 4000
    @State private var attenuation: Double = -36
    @State private var ear: NTEar = .both
    @State private var playing: Bool = false
    @State private var playingWhich: Int = -1     // -1 none, 0 = A, 1 = B

    @State private var lowLog: Double = 8.0        // 256 Hz
    @State private var highLog: Double = 13.5507   // 12 kHz
    @State private var round: Int = 0
    @State private var octaveChecked: Bool = false
    @State private var octaveChoice: Int = 1

    private let maxRounds = 7

    var body: some View {
        NTDetailScreen(title: "Pitch match",
                       subtitle: "Find the frequency closest to the sound you hear.") {
            NTSafetyNote(text: "This is a self-matching exercise, not an audiometric hearing test. It cannot measure hearing loss. Keep the level low throughout.")

            switch stage {
            case .intro: introSection
            case .free: freeSection
            case .bracket: bracketSection
            case .octave: octaveSection
            case .result: resultSection
            }
        }
        .onAppear {
            synth.beginMeasurementMode()
            if let f = store.profile.matchedFrequency, f > 100 { frequency = f }
            if let e = NTEar(rawValue: store.profile.preferredEarRaw) { ear = e }
            synth.setEar(ear)
        }
        .onDisappear {
            synth.endMeasurementMode()
        }
        // The engine stops itself on an interruption, on headphones being unplugged and
        // on backgrounding. Follow it, or the button keeps offering to stop silence.
        .onChange(of: synth.isPlaying) { playingNow in
            if !playingNow {
                playing = false
                playingWhich = -1
            }
        }
    }

    // MARK: Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before you start")
                        .font(NTTheme.rounded(17, .bold))
                        .foregroundColor(NTTheme.ink)
                    para("Use headphones if you have them, sit somewhere quiet, and set your device volume low before the first tone plays.")
                    para("You are looking for the frequency that sounds closest to your own tinnitus. Nobody gets this exact, and the result is expected to move between attempts. That is normal and it is why the app keeps a history rather than a single number.")
                    para("If your tinnitus is a hiss or a rushing sound rather than a tone, you will find a region rather than a point. Pick the centre of that region — a wider notch on the Sound tab will cover the imprecision.")
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a method")
                        .font(NTTheme.rounded(16, .semibold))
                        .foregroundColor(NTTheme.ink)
                    NTSegmented(options: ["Free sweep", "Bracketing"], index: $mode)
                    Text(mode == 0
                         ? "Turn a logarithmic dial from 250 Hz to 12 kHz and listen for the closest point. Direct, but easy to talk yourself around in circles."
                         : "The app plays two tones an octave apart. You say which is closer, the search area halves, and after seven rounds it has converged. Less tiring and usually more repeatable.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    NTEarPicker(ear: $ear) { e in synth.setEar(e) }

                    NTParamRow(label: "Starting level", value: String(format: "%.0f dB", attenuation)) {
                        NTSlider(value: Binding(get: { attenuation },
                                                set: { v in attenuation = v.rounded(); updateTone() }),
                                 range: -75 ... -12, ticks: 7, tint: NTTheme.cyan)
                    }

                    Button(action: {
                        if mode == 0 {
                            stage = .free
                        } else {
                            lowLog = 8.0
                            highLog = 13.5507
                            round = 0
                            stage = .bracket
                        }
                    }) {
                        NTButtonLabel(title: "Start", filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: Free sweep

    private var freeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(spacing: 14) {
                    NTFrequencyDial(frequency: Binding(get: { frequency },
                                                       set: { v in
                                                           frequency = v
                                                           if playing { updateTone() }
                                                       }),
                                    minHz: 250, maxHz: 12000,
                                    diameter: min(260, NTLayout.screenW - 90))

                    HStack(spacing: 10) {
                        Button(action: { nudge(-1.0 / 12.0) }) {
                            NTButtonLabel(title: "− semitone", filled: false, tint: NTTheme.inkDim, compact: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Button(action: { nudge(1.0 / 12.0) }) {
                            NTButtonLabel(title: "+ semitone", filled: false, tint: NTTheme.inkDim, compact: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    NTAuditionButton(playing: playing, title: "Play this tone") {
                        togglePlay(frequency)
                    }
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 12) {
                    NTParamRow(label: "Level", value: String(format: "%.0f dB", attenuation)) {
                        NTSlider(value: Binding(get: { attenuation },
                                                set: { v in attenuation = v.rounded(); updateTone() }),
                                 range: -75 ... -12, ticks: 7, tint: NTTheme.cyan)
                    }
                    NTInlineDisclaimer(text: "Relative in-app decibels. This number describes the app's own output, not any real-world sound level.")
                    Button(action: {
                        stopTone()
                        stage = .octave
                    }) {
                        NTButtonLabel(title: "This is closest", filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { stopTone(); stage = .intro }) {
                        NTButtonLabel(title: "Back to the start", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func nudge(_ octaves: Double) {
        frequency = NTNum.clamp(frequency * pow(2.0, octaves), 250, 12000)
        if playing { updateTone() }
    }

    // MARK: Bracketing

    private var bracketMid: Double { (lowLog + highLog) / 2 }
    private var bracketSeparation: Double { min(1.0, (highLog - lowLog) / 2) }
    private var bracketA: Double { pow(2.0, bracketMid - bracketSeparation / 2) }
    private var bracketB: Double { pow(2.0, bracketMid + bracketSeparation / 2) }

    private var bracketSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("ROUND \(round + 1) OF \(maxRounds)")
                            .font(NTTheme.mono(11, .semibold))
                            .foregroundColor(NTTheme.cyan)
                            .tracking(1.4)
                        Spacer()
                        Text(String(format: "%.2f octave span", highLog - lowLog))
                            .font(NTTheme.mono(10))
                            .foregroundColor(NTTheme.inkFaint)
                    }

                    Canvas { ctx, size in
                        let w = size.width, h = size.height
                        let lo = 8.0, hi = 13.5507
                        func x(_ v: Double) -> CGFloat {
                            CGFloat(NTNum.safeDiv(v - lo, hi - lo)) * w
                        }
                        ctx.fill(Path(roundedRect: CGRect(x: 0, y: h / 2 - 3, width: w, height: 6), cornerRadius: 3),
                                 with: .color(NTTheme.panelHigh))
                        ctx.fill(Path(roundedRect: CGRect(x: x(lowLog), y: h / 2 - 3,
                                                          width: max(3, x(highLog) - x(lowLog)), height: 6),
                                      cornerRadius: 3),
                                 with: .color(NTTheme.cyanDim))
                        for (v, c) in [(log2(bracketA), NTTheme.seriesPitch), (log2(bracketB), NTTheme.seriesLoud)] {
                            let px = x(v)
                            ctx.fill(Path(ellipseIn: CGRect(x: px - 5, y: h / 2 - 5, width: 10, height: 10)),
                                     with: .color(c))
                        }
                    }
                    .frame(height: 26)

                    Text("Play both, then say which one is closer to your own sound. If neither is close, the answer is still whichever is less far away.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        toneButton(label: "A", freq: bracketA, index: 0, tint: NTTheme.seriesPitch)
                        toneButton(label: "B", freq: bracketB, index: 1, tint: NTTheme.seriesLoud)
                    }

                    HStack(spacing: 10) {
                        Button(action: { choose(lower: true) }) {
                            NTButtonLabel(title: "A is closer", filled: true, tint: NTTheme.seriesPitch, compact: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Button(action: { choose(lower: false) }) {
                            NTButtonLabel(title: "B is closer", filled: true, tint: NTTheme.seriesLoud, compact: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: { stopTone() }) {
                        NTButtonLabel(title: "Stop sound", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    NTParamRow(label: "Level", value: String(format: "%.0f dB", attenuation)) {
                        NTSlider(value: Binding(get: { attenuation },
                                                set: { v in attenuation = v.rounded(); updateTone() }),
                                 range: -75 ... -12, ticks: 7, tint: NTTheme.cyan)
                    }
                    Button(action: {
                        stopTone()
                        lowLog = 8.0
                        highLog = 13.5507
                        round = 0
                    }) {
                        NTButtonLabel(title: "Start the search again", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { stopTone(); stage = .intro }) {
                        NTButtonLabel(title: "Back to the start", filled: false, tint: NTTheme.inkFaint, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func toneButton(label: String, freq: Double, index: Int, tint: Color) -> some View {
        Button(action: {
            if playing && playingWhich == index {
                stopTone()
            } else {
                playingWhich = index
                startTone(freq)
            }
        }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(NTTheme.mono(19, .bold))
                    .foregroundColor(playing && playingWhich == index ? NTTheme.deep : tint)
                Text(NTNum.hz(freq))
                    .font(NTTheme.mono(11))
                    .foregroundColor(playing && playingWhich == index ? NTTheme.deep.opacity(0.8) : NTTheme.inkFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(playing && playingWhich == index ? tint : NTTheme.panelHigh)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.55), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func choose(lower: Bool) {
        let mid = bracketMid
        if lower { highLog = mid } else { lowLog = mid }
        round += 1
        stopTone()
        if round >= maxRounds {
            frequency = NTNum.clamp(pow(2.0, (lowLog + highLog) / 2), 250, 12000)
            stage = .octave
        }
    }

    // MARK: Octave check

    private var octaveCandidates: [Double] {
        [NTNum.clamp(frequency / 2, 100, 14000),
         frequency,
         NTNum.clamp(frequency * 2, 100, 14000)]
    }

    private var octaveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Octave check")
                        .font(NTTheme.rounded(17, .bold))
                        .foregroundColor(NTTheme.ink)
                    para("Octave confusion is real and extremely common: people frequently match a frequency exactly one octave above or below the sound they actually hear. This step exists to catch it.")
                    para("Listen to all three and pick the one that is genuinely closest. If the middle one still wins, that is a good sign your match is stable.")

                    ForEach(0..<3, id: \.self) { i in
                        let f = octaveCandidates[i]
                        Button(action: {
                            octaveChoice = i
                            if playing && playingWhich == i {
                                stopTone()
                            } else {
                                playingWhich = i
                                startTone(f)
                            }
                        }) {
                            HStack(spacing: 12) {
                                NTSelectDot(size: 20, selected: octaveChoice == i)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NTNum.hz(f))
                                        .font(NTTheme.mono(16, .semibold))
                                        .foregroundColor(NTTheme.ink)
                                    Text(i == 0 ? "One octave below" : (i == 1 ? "Your match" : "One octave above"))
                                        .font(NTTheme.rounded(11))
                                        .foregroundColor(NTTheme.inkFaint)
                                }
                                Spacer(minLength: 0)
                                if playing && playingWhich == i {
                                    NTStopGlyph(size: 18, color: NTTheme.cyan)
                                } else {
                                    NTPlayGlyph(size: 18, color: NTTheme.cyan)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(octaveChoice == i ? NTTheme.panelHigh : NTTheme.panel))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(octaveChoice == i ? NTTheme.cyan.opacity(0.6) : NTTheme.gridFaint, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: {
                        frequency = octaveCandidates[min(max(0, octaveChoice), 2)]
                        octaveChecked = true
                        stopTone()
                        stage = .result
                    }) {
                        NTButtonLabel(title: "Use this one", filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        octaveChecked = false
                        stopTone()
                        stage = .result
                    }) {
                        NTButtonLabel(title: "Skip the octave check", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel(tint: NTTheme.cyanDim) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MATCHED PITCH")
                        .font(NTTheme.mono(10, .semibold))
                        .foregroundColor(NTTheme.cyan)
                        .tracking(1.6)
                    Text(NTNum.hz(frequency))
                        .font(NTTheme.mono(38, .bold))
                        .foregroundColor(NTTheme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    NTSpectrumChart(layers: [NTLayerConfig(kind: .notchedNoise, colour: .pink,
                                                           frequency: frequency, notchOctaves: 1.0, level: 0.6)],
                                    markerFrequency: frequency, height: 100)

                    Text("This is how a one-octave notch would sit around your match. The Sound tab builds its top card from exactly this.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        NTStatTile(caption: "Method", value: mode == 0 ? "Sweep" : "Bracket",
                                   detail: mode == 0 ? "Free dial" : "\(round) rounds", tint: NTTheme.cyan)
                        NTStatTile(caption: "Octave check", value: octaveChecked ? "Done" : "Skipped",
                                   detail: octaveChecked ? "Confirmed against both neighbours" : "Worth doing next time",
                                   tint: octaveChecked ? NTTheme.seriesMask : NTTheme.inkDim)
                    }

                    NTInlineDisclaimer(text: "A self-matched pitch. It is not an audiometric measurement and says nothing about your hearing.")

                    Button(action: save) {
                        NTButtonLabel(title: "Save this match", filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { stage = .intro }) {
                        NTButtonLabel(title: "Try again without saving", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func save() {
        stopTone()
        store.recordPitch(NTPitchRecord(frequency: frequency,
                                        method: mode == 0 ? "sweep" : "bracket",
                                        octaveChecked: octaveChecked,
                                        ear: ear,
                                        rounds: mode == 0 ? 0 : round))
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: Tone control

    private func toneConfig(_ f: Double) -> NTLayerConfig {
        NTLayerConfig(kind: .pureTone, colour: .white, frequency: f, level: 1.0)
    }

    private func startTone(_ f: Double) {
        synth.setEar(ear)
        synth.playMeasurement(toneConfig(f), attenuationDb: attenuation)
        playing = true
    }

    private func togglePlay(_ f: Double) {
        if playing { stopTone() } else { playingWhich = -1; startTone(f) }
    }

    private func updateTone() {
        guard playing else { return }
        let f: Double
        if stage == .bracket {
            f = playingWhich == 1 ? bracketB : bracketA
        } else if stage == .octave {
            f = octaveCandidates[min(max(0, playingWhich), 2)]
        } else {
            f = frequency
        }
        synth.updateMeasurement(toneConfig(f), attenuationDb: attenuation)
    }

    private func stopTone() {
        synth.stopMeasurementTone()
        playing = false
        playingWhich = -1
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(13))
            .foregroundColor(NTTheme.inkDim)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 2. Loudness match

struct NTLoudnessMatchView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Environment(\.presentationMode) private var presentationMode

    @State private var started: Bool = false
    @State private var attenuation: Double = -60
    @State private var playing: Bool = false
    @State private var ear: NTEar = .both

    private var frequency: Double {
        NTNum.clamp(store.profile.matchedFrequency ?? 4000, 100, 12000)
    }

    var body: some View {
        NTDetailScreen(title: "Loudness match",
                       subtitle: "How loud a tone has to be to sound like your tinnitus.") {

            NTSafetyNote(text: "Raise the tone one step at a time and stop the moment it matches. Never keep going past comfortable in order to reach a number.")

            if !store.profile.hasPitch {
                NTEmptyState(title: "A matched pitch is needed first",
                             message: "This exercise plays a tone at your matched frequency, so the pitch match has to come first. Go back and run it, then return here.")
            } else if !started {
                introCard
            } else {
                ladderCard
            }
        }
        .onAppear {
            synth.beginMeasurementMode()
            if let e = NTEar(rawValue: store.profile.preferredEarRaw) { ear = e }
            synth.setEar(ear)
        }
        .onDisappear {
            synth.endMeasurementMode()
        }
        .onChange(of: synth.isPlaying) { playingNow in
            if !playingNow { playing = false }
        }
    }

    private var introCard: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 11) {
                Text("How this works")
                    .font(NTTheme.rounded(17, .bold))
                    .foregroundColor(NTTheme.ink)
                para("A tone at " + NTNum.hz(frequency) + " starts far below anything you could confuse with your tinnitus. Raise it one decibel at a time until it sounds about as loud as the sound you hear, then record it.")
                para("The result is stored as relative in-app decibels below the app's own reference level. It is not dB SL and not dB HL — your phone and your headphones have no calibrated output, so no number here can be compared with a clinical measurement or with anyone else's result.")
                para("What it is good for is comparison against your own earlier attempts, which is exactly what the history chart on the Measure tab shows.")

                NTEarPicker(ear: $ear) { e in synth.setEar(e) }

                Button(action: {
                    attenuation = -60
                    started = true
                }) {
                    NTButtonLabel(title: "Start at the quietest step", filled: true, tint: NTTheme.seriesLoud)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TONE")
                                .font(NTTheme.mono(9, .semibold))
                                .foregroundColor(NTTheme.inkFaint)
                                .tracking(1.2)
                            Text(NTNum.hz(frequency))
                                .font(NTTheme.mono(20, .semibold))
                                .foregroundColor(NTTheme.ink)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("EAR")
                                .font(NTTheme.mono(9, .semibold))
                                .foregroundColor(NTTheme.inkFaint)
                                .tracking(1.2)
                            Text(ear.title)
                                .font(NTTheme.mono(20, .semibold))
                                .foregroundColor(NTTheme.ink)
                        }
                    }

                    NTAuditionButton(playing: playing, title: "Play the tone", action: togglePlay, tint: NTTheme.seriesLoud)

                    NTLevelLadder(attenuation: $attenuation, onChange: { _ in updateTone() })

                    Text("Raise until the tone is about as loud as your tinnitus. Most people land somewhere between the far quiet end and the middle of the range.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: save) {
                        NTButtonLabel(title: String(format: "This matches — record %.0f dB", attenuation),
                                      filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        stopTone()
                        started = false
                    }) {
                        NTButtonLabel(title: "Start over", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())

                    NTInlineDisclaimer(text: "A relative in-app value only. It is not a clinical loudness measurement and cannot be compared with one.")
                }
            }
        }
    }

    private func toneConfig() -> NTLayerConfig {
        NTLayerConfig(kind: .pureTone, colour: .white, frequency: frequency, level: 1.0)
    }

    private func togglePlay() {
        if playing {
            stopTone()
        } else {
            synth.setEar(ear)
            synth.playMeasurement(toneConfig(), attenuationDb: attenuation)
            playing = true
        }
    }

    private func updateTone() {
        guard playing else { return }
        synth.updateMeasurement(toneConfig(), attenuationDb: attenuation)
    }

    private func stopTone() {
        synth.stopMeasurementTone()
        playing = false
    }

    private func save() {
        stopTone()
        store.recordLoudness(NTLoudnessRecord(frequency: frequency, relativeDb: attenuation, ear: ear))
        presentationMode.wrappedValue.dismiss()
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(13))
            .foregroundColor(NTTheme.inkDim)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 3. Minimum masking level

struct NTMaskingLevelView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Environment(\.presentationMode) private var presentationMode

    @State private var started: Bool = false
    @State private var attenuation: Double = -60
    @State private var playing: Bool = false
    @State private var colour: NTNoiseColour = .white

    var body: some View {
        NTDetailScreen(title: "Minimum masking level",
                       subtitle: "The quietest noise at which your tinnitus stops being audible.") {

            NTSafetyNote(text: "If the noise reaches an uncomfortable level before your tinnitus is covered, stop and record that instead. Not being able to cover it comfortably is a real and useful result.")

            if !started {
                introCard
            } else {
                ladderCard
            }
        }
        .onAppear {
            synth.beginMeasurementMode()
            synth.setEar(.both)
            colour = store.profile.maskingColour
        }
        .onDisappear {
            synth.endMeasurementMode()
        }
        .onChange(of: synth.isPlaying) { playingNow in
            if !playingNow { playing = false }
        }
    }

    private var introCard: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 11) {
                Text("How this works")
                    .font(NTTheme.rounded(17, .bold))
                    .foregroundColor(NTTheme.ink)
                para("Noise starts far below your tinnitus. Raise it one decibel at a time and stop at the very first step where you can no longer pick your tinnitus out. That step is your minimum masking level.")
                para("A low number means a small amount of sound covers it, which usually makes sound approaches easier to live with. A high number, or no coverage at a comfortable level, points toward partial masking or distraction rather than cover.")
                para("Like every number in this app it is in relative in-app decibels and is only meaningful against your own earlier attempts.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOISE USED")
                        .font(NTTheme.mono(9, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.0)
                    NTColourPicker(colour: $colour) { _ in updateNoise() }
                    Text("White noise is the usual choice because it spreads energy evenly. Pink is gentler and many people find it easier to sit with.")
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: {
                    attenuation = -60
                    started = true
                }) {
                    NTButtonLabel(title: "Start at the quietest step", filled: true, tint: NTTheme.seriesMask)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NTPanel {
                VStack(alignment: .leading, spacing: 14) {
                    NTSpectrumChart(layers: [NTLayerConfig(kind: .colourNoise, colour: colour, level: 0.7)],
                                    markerFrequency: store.profile.matchedFrequency,
                                    height: 84, accent: NTTheme.seriesMask)

                    NTAuditionButton(playing: playing, title: "Play the noise", action: togglePlay, tint: NTTheme.seriesMask)

                    NTLevelLadder(attenuation: $attenuation, onChange: { _ in updateNoise() })

                    Text("Stop at the first step where your tinnitus disappears into the noise, not at the point where the noise feels loud.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { save(covered: true) }) {
                        NTButtonLabel(title: String(format: "It is covered — record %.0f dB", attenuation),
                                      filled: true, tint: NTTheme.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { save(covered: false) }) {
                        NTButtonLabel(title: "Not covered at a comfortable level", filled: false,
                                      tint: NTTheme.amber)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        stopNoise()
                        started = false
                    }) {
                        NTButtonLabel(title: "Start over", filled: false, tint: NTTheme.inkDim, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())

                    NTInlineDisclaimer(text: "Relative in-app decibels. Not a clinical masking measurement.")
                }
            }
        }
    }

    private func noiseConfig() -> NTLayerConfig {
        NTLayerConfig(kind: .colourNoise, colour: colour, level: 1.0)
    }

    private func togglePlay() {
        if playing {
            stopNoise()
        } else {
            synth.playMeasurement(noiseConfig(), attenuationDb: attenuation)
            playing = true
        }
    }

    private func updateNoise() {
        guard playing else { return }
        synth.updateMeasurement(noiseConfig(), attenuationDb: attenuation)
    }

    private func stopNoise() {
        synth.stopMeasurementTone()
        playing = false
    }

    private func save(covered: Bool) {
        stopNoise()
        store.recordMasking(NTMaskingRecord(relativeDb: attenuation, colour: colour, notCovered: !covered))
        presentationMode.wrappedValue.dismiss()
    }

    private func para(_ text: String) -> some View {
        Text(text)
            .font(NTTheme.rounded(13))
            .foregroundColor(NTTheme.inkDim)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

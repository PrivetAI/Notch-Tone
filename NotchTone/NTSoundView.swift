import SwiftUI

enum NTSoundSheet: Identifiable {
    case volumeWarning
    case addGenerator
    case savePreset

    var id: Int {
        switch self {
        case .volumeWarning: return 0
        case .addGenerator: return 1
        case .savePreset: return 2
        }
    }
}

struct NTSoundView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Binding var selectedTab: Int

    @State private var sheet: NTSoundSheet? = nil
    @State private var wavePhase: Double = 0
    @State private var meter: Double = 0
    @State private var presetName: String = ""
    @State private var pendingPlay: Bool = false
    @State private var expandedLayer: UUID? = nil

    private let ticker = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        NTScreen(title: "Sound",
                 subtitle: "Generated one sample at a time. No audio files anywhere in this app.") {

            tunedCard
            transportCard
            layerSection
            presetSection

            NTInlineDisclaimer(text: "Notch Tone is a self-management and sound-generation tool. It is not a medical device and does not diagnose, treat or cure anything.")
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .volumeWarning:
                NTVolumeWarningView(isPresented: Binding(get: { sheet != nil },
                                                        set: { if !$0 { sheet = nil } }),
                                    onAccept: {
                                        store.settings.hasAcceptedVolumeWarning = true
                                        if pendingPlay {
                                            pendingPlay = false
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                                synth.play()
                                            }
                                        }
                                    })
            case .addGenerator:
                NTGeneratorPicker(isPresented: Binding(get: { sheet != nil },
                                                       set: { if !$0 { sheet = nil } }),
                                  profileFrequency: store.profile.matchedFrequency) { cfg in
                    synth.addLayer(cfg)
                    expandedLayer = cfg.id
                }
            case .savePreset:
                NTSavePresetSheet(isPresented: Binding(get: { sheet != nil },
                                                       set: { if !$0 { sheet = nil } }),
                                  name: $presetName) {
                    let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let final = trimmed.isEmpty ? "Saved \(NTFormat.dayLabel.string(from: Date()))" : trimmed
                    let detail = synth.layers.filter { $0.enabled }.map { $0.readout }.joined(separator: " + ")
                    store.userPresets.insert(NTPreset(name: final, detail: detail, layers: synth.layers), at: 0)
                    presetName = ""
                }
            }
        }
        .onReceive(ticker) { _ in
            if synth.isPlaying {
                wavePhase += 0.22
                if wavePhase > 1000 { wavePhase = 0 }
                meter = meter * 0.55 + synth.meterLevel * 0.45
            } else if meter > 0.001 {
                meter *= 0.7
            }
        }
        .onDisappear {
            store.settings.lastMasterLevel = synth.masterLevel
        }
    }

    // MARK: - Tuned for you

    @ViewBuilder
    private var tunedCard: some View {
        if let f = store.profile.matchedFrequency, store.profile.hasPitch {
            NTPanel(tint: NTTheme.cyanDim) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TUNED FOR YOU")
                                .font(NTTheme.mono(10, .semibold))
                                .foregroundColor(NTTheme.cyan)
                                .tracking(1.6)
                            Text("Notched noise at " + NTNum.hz(f))
                                .font(NTTheme.rounded(19, .bold))
                                .foregroundColor(NTTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        NTBarsGlyph(size: 26, color: NTTheme.cyanDim)
                    }

                    Text("The band around your matched frequency is removed by four cascaded band-reject sections. The gap below is drawn from those exact coefficients.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    NTSpectrumChart(layers: tunedLayers(f), markerFrequency: f, height: 108)

                    HStack(spacing: 10) {
                        Button(action: { loadTuned(f) }) {
                            NTButtonLabel(title: isTunedLoaded(f) ? "Loaded" : "Load this",
                                          filled: !isTunedLoaded(f),
                                          tint: NTTheme.cyan, compact: true)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            loadTuned(f)
                            requestPlay()
                        }) {
                            HStack(spacing: 8) {
                                NTPlayGlyph(size: 15, color: NTTheme.deep)
                                Text("Play")
                                    .font(NTTheme.rounded(13, .semibold))
                                    .foregroundColor(NTTheme.deep)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(NTTheme.cyan))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer(minLength: 0)
                    }

                    if let at = store.profile.matchedAt {
                        Text("Matched " + NTFormat.fullDate.string(from: at) + ". Re-match on the Measure tab whenever the sound changes.")
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            NTEmptyState(title: "No matched frequency yet",
                         message: "The notched preset is built around a frequency you have matched yourself. Until then, the generators below all still work — you can pick a centre frequency by hand.",
                         actionTitle: "Open the Measure tab") {
                selectedTab = 1
            }
        }
    }

    private func tunedLayers(_ f: Double) -> [NTLayerConfig] {
        [NTLayerConfig(kind: .notchedNoise, colour: .pink, frequency: f, notchOctaves: 1.0, level: 0.62)]
    }

    private func isTunedLoaded(_ f: Double) -> Bool {
        guard synth.layers.count == 1, let l = synth.layers.first else { return false }
        return l.kind == .notchedNoise && abs(l.frequency - f) < 1 && abs(l.notchOctaves - 1.0) < 0.01
    }

    private func loadTuned(_ f: Double) {
        synth.setLayers(tunedLayers(f))
    }

    // MARK: - Transport

    private var transportCard: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Button(action: { if synth.isPlaying { synth.pause() } else { requestPlay() } }) {
                        ZStack {
                            Circle()
                                .fill(synth.isPlaying ? NTTheme.panelHigh
                                                      : (canPlay ? NTTheme.cyan : NTTheme.panelHigh))
                            Circle()
                                .stroke(NTTheme.cyan.opacity(synth.isPlaying ? 0.8 : 0), lineWidth: 1.4)
                            if synth.isPlaying {
                                NTPauseGlyph(size: 26, color: NTTheme.cyan)
                            } else {
                                NTPlayGlyph(size: 26, color: canPlay ? NTTheme.deep : NTTheme.inkFaint)
                            }
                        }
                        .frame(width: 58, height: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canPlay && !synth.isPlaying)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusLine)
                            .font(NTTheme.mono(13, .semibold))
                            .foregroundColor(synth.isFadingOut ? NTTheme.amber : NTTheme.ink)
                        Text(timerLine)
                            .font(NTTheme.mono(11))
                            .foregroundColor(NTTheme.inkFaint)
                    }

                    Spacer(minLength: 0)

                    if synth.isPlaying || synth.elapsedSeconds > 0 {
                        Button(action: { synth.stop() }) {
                            VStack(spacing: 4) {
                                NTStopGlyph(size: 22, color: NTTheme.inkDim)
                                Text("Stop")
                                    .font(NTTheme.rounded(10))
                                    .foregroundColor(NTTheme.inkDim)
                            }
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if synth.engineFailed {
                    NTSafetyNote(text: "The audio engine could not start. Check that the device is not in a call and that another app is not holding exclusive audio, then try again.")
                }

                NTWaveStrip(layers: synth.layers, phase: wavePhase,
                            level: synth.isPlaying ? synth.masterLevel : 0.12, height: 54)

                if store.settings.showLevelReadout {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LEVEL")
                                .font(NTTheme.mono(10, .semibold))
                                .foregroundColor(NTTheme.inkFaint)
                                .tracking(1.4)
                            Spacer()
                            Text(String(format: "%.0f%%", synth.masterLevel * 100))
                                .font(NTTheme.mono(24, .bold))
                                .foregroundColor(NTTheme.cyan)
                        }
                        NTLevelMeter(level: meter, capFraction: 0.85)
                    }
                }

                NTSlider(value: Binding(get: { synth.masterLevel },
                                        set: { v in
                                            synth.masterLevel = v
                                            synth.publishMaster()
                                            store.settings.lastMasterLevel = v
                                        }),
                         range: 0...1, ticks: 10, tint: NTTheme.cyan)

                VStack(alignment: .leading, spacing: 6) {
                    Text("SLEEP TIMER")
                        .font(NTTheme.mono(10, .semibold))
                        .foregroundColor(NTTheme.inkFaint)
                        .tracking(1.4)
                    HStack(spacing: 6) {
                        ForEach(0..<NTSleepTimer.options.count, id: \.self) { i in
                            let minutes = NTSleepTimer.options[i]
                            Button(action: { synth.setTimer(minutes: minutes) }) {
                                Text(NTSleepTimer.label(minutes))
                                    .font(NTTheme.mono(11, .medium))
                                    .foregroundColor(synth.timerMinutes == minutes ? NTTheme.deep : NTTheme.inkDim)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(synth.timerMinutes == minutes ? NTTheme.cyan : NTTheme.panelHigh)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Text("Timed sessions fade out slowly over the last " +
                         NTFormat.durationWords(Int(store.settings.endFadeSeconds)) + " rather than cutting off.")
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// There must be at least one enabled generator before playback means anything.
    private var canPlay: Bool {
        synth.layers.contains(where: { $0.enabled && $0.level > 0.001 })
    }

    private var statusLine: String {
        if synth.isFadingOut { return "Fading out" }
        if synth.isPlaying { return "Playing · " + NTFormat.duration(synth.elapsedSeconds) }
        if synth.layers.isEmpty { return "No generators" }
        if !canPlay { return "Every layer is muted" }
        return "Ready"
    }

    private var timerLine: String {
        if synth.timerMinutes == 0 { return "Open-ended session" }
        if synth.isPlaying { return NTFormat.duration(synth.remainingSeconds) + " remaining" }
        return NTSleepTimer.longLabel(synth.timerMinutes)
    }

    private func requestPlay() {
        guard canPlay else { return }
        if !store.settings.hasAcceptedVolumeWarning {
            pendingPlay = true
            sheet = .volumeWarning
            return
        }
        synth.play()
    }

    // MARK: - Layer stack

    private var layerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Layer stack",
                            caption: "Up to three generators at once. Each one keeps its own parameters and its own level.")

            if synth.layers.isEmpty {
                NTEmptyState(title: "The stack is empty",
                             message: "Add a generator to start building a sound. Notched noise is the one this app is built around, but every generator here is synthesised the same way.",
                             actionTitle: "Add a generator") {
                    sheet = .addGenerator
                }
            } else {
                ForEach(Array(synth.layers.enumerated()), id: \.element.id) { pair in
                    NTLayerCard(index: pair.offset,
                                config: pair.element,
                                expanded: expandedLayer == pair.element.id,
                                profileFrequency: store.profile.matchedFrequency,
                                onToggleExpand: {
                                    expandedLayer = expandedLayer == pair.element.id ? nil : pair.element.id
                                },
                                onChange: { mutate in
                                    synth.updateLayer(pair.offset, mutate)
                                },
                                onRemove: {
                                    if expandedLayer == pair.element.id { expandedLayer = nil }
                                    synth.removeLayer(at: pair.offset)
                                })
                }
            }

            HStack(spacing: 10) {
                Button(action: { sheet = .addGenerator }) {
                    HStack(spacing: 7) {
                        NTPlusGlyph(size: 15, color: synth.layers.count < NTSynth.maxLayers ? NTTheme.cyan : NTTheme.inkFaint)
                        Text(synth.layers.count < NTSynth.maxLayers ? "Add generator" : "Stack is full")
                            .font(NTTheme.rounded(13, .semibold))
                            .foregroundColor(synth.layers.count < NTSynth.maxLayers ? NTTheme.cyan : NTTheme.inkFaint)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(synth.layers.count < NTSynth.maxLayers ? NTTheme.cyan.opacity(0.6) : NTTheme.panelEdge, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(synth.layers.count >= NTSynth.maxLayers)

                if !synth.layers.isEmpty {
                    Button(action: { sheet = .savePreset }) {
                        NTButtonLabel(title: "Save preset", filled: false, tint: NTTheme.indigo, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer(minLength: 0)
            }

            if !synth.layers.isEmpty {
                NTPanel(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMPOSITE SPECTRUM")
                            .font(NTTheme.mono(10, .semibold))
                            .foregroundColor(NTTheme.inkFaint)
                            .tracking(1.4)
                        NTSpectrumChart(layers: synth.layers,
                                        markerFrequency: store.profile.matchedFrequency,
                                        height: 120)
                        Text("Computed from the running filter coefficients. The amber marker is your matched frequency.")
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Presets",
                            caption: "Eight authored starting points. Those built on a notch follow your matched frequency automatically.")

            ForEach(NTPresetLibrary.builtIn(profileFrequency: store.profile.matchedFrequency)) { preset in
                presetRow(preset, deletable: false)
            }

            if !store.userPresets.isEmpty {
                NTSectionHeader(title: "Your presets")
                ForEach(store.userPresets) { preset in
                    presetRow(preset, deletable: true)
                }
            }
        }
    }

    private func presetRow(_ preset: NTPreset, deletable: Bool) -> some View {
        NTPanel(padding: 13) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(preset.name)
                                .font(NTTheme.rounded(15, .semibold))
                                .foregroundColor(NTTheme.ink)
                            if preset.followsProfile && store.profile.hasPitch {
                                Text("TUNED")
                                    .font(NTTheme.mono(8, .semibold))
                                    .foregroundColor(NTTheme.deep)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(NTTheme.cyan))
                            }
                        }
                        Text(preset.detail)
                            .font(NTTheme.rounded(12))
                            .foregroundColor(NTTheme.inkDim)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                NTSpectrumChart(layers: preset.resolvedLayers(profileFrequency: store.profile.matchedFrequency),
                                markerFrequency: preset.followsProfile ? store.profile.matchedFrequency : nil,
                                height: 60, showAxis: false, accent: NTTheme.cyanDim)

                HStack(spacing: 10) {
                    Button(action: {
                        synth.setLayers(preset.resolvedLayers(profileFrequency: store.profile.matchedFrequency))
                        expandedLayer = nil
                    }) {
                        NTButtonLabel(title: "Load", filled: false, tint: NTTheme.cyan, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        synth.setLayers(preset.resolvedLayers(profileFrequency: store.profile.matchedFrequency))
                        expandedLayer = nil
                        requestPlay()
                    }) {
                        NTButtonLabel(title: "Play", filled: true, tint: NTTheme.cyan, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer(minLength: 0)

                    if deletable {
                        Button(action: {
                            store.userPresets.removeAll { $0.id == preset.id }
                        }) {
                            HStack(spacing: 5) {
                                NTCrossGlyph(size: 12, color: NTTheme.inkFaint)
                                Text("Delete")
                                    .font(NTTheme.rounded(12))
                                    .foregroundColor(NTTheme.inkFaint)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Layer card

struct NTLayerCard: View {
    let index: Int
    let config: NTLayerConfig
    let expanded: Bool
    let profileFrequency: Double?
    let onToggleExpand: () -> Void
    let onChange: ((inout NTLayerConfig) -> Void) -> Void
    let onRemove: () -> Void

    var body: some View {
        NTPanel(padding: 13, tint: config.enabled ? NTTheme.panelEdge : NTTheme.gridFaint) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: { onChange { $0.enabled.toggle() } }) {
                        NTSelectDot(size: 20, selected: config.enabled)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.displayName)
                            .font(NTTheme.rounded(15, .semibold))
                            .foregroundColor(config.enabled ? NTTheme.ink : NTTheme.inkFaint)
                        Text(config.readout)
                            .font(NTTheme.mono(11))
                            .foregroundColor(NTTheme.inkFaint)
                    }

                    Spacer(minLength: 0)

                    Button(action: onToggleExpand) {
                        NTChevronGlyph(size: 18, color: NTTheme.cyan, rotation: expanded ? 270 : 90)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onRemove) {
                        NTCrossGlyph(size: 15, color: NTTheme.inkFaint)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                NTParamRow(label: "Layer level", value: String(format: "%.0f%%", config.level * 100)) {
                    NTSlider(value: Binding(get: { config.level },
                                            set: { v in onChange { $0.level = v } }),
                             range: 0...1, ticks: 10, tint: NTTheme.cyanDim)
                }

                if expanded {
                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)
                    parameterControls
                }
            }
        }
    }

    @ViewBuilder
    private var parameterControls: some View {
        switch config.kind {
        case .notchedNoise:
            NTParamRow(label: "Notch centre", value: NTNum.hz(config.frequency)) {
                NTLogFreqSlider(frequency: Binding(get: { config.frequency },
                                                   set: { v in onChange { $0.frequency = v } }),
                                minHz: 250, maxHz: 12000)
            }
            widthPicker(label: "Notch width",
                        value: config.notchOctaves,
                        set: { v in onChange { $0.notchOctaves = v } })
            colourControl(limitedToBroadband: true)
            if let pf = profileFrequency, abs(pf - config.frequency) > 1 {
                Button(action: { onChange { $0.frequency = pf } }) {
                    NTButtonLabel(title: "Re-centre on " + NTNum.hz(pf), filled: false,
                                  tint: NTTheme.amber, compact: true)
                }
                .buttonStyle(PlainButtonStyle())
            }

        case .bandNoise:
            NTParamRow(label: "Band centre", value: NTNum.hz(config.frequency)) {
                NTLogFreqSlider(frequency: Binding(get: { config.frequency },
                                                   set: { v in onChange { $0.frequency = v } }),
                                minHz: 150, maxHz: 12000)
            }
            widthPicker(label: "Band width",
                        value: config.bandOctaves,
                        set: { v in onChange { $0.bandOctaves = v } })
            colourControl(limitedToBroadband: true)

        case .pureTone:
            NTParamRow(label: "Frequency", value: NTNum.hz(config.frequency)) {
                NTLogFreqSlider(frequency: Binding(get: { config.frequency },
                                                   set: { v in onChange { $0.frequency = v } }),
                                minHz: 100, maxHz: 12000, tint: NTTheme.seriesLoud)
            }
            NTInlineDisclaimer(text: "A pure tone is the most fatiguing sound in the app. Keep this layer well below the level of the noise layers.")

        case .colourNoise:
            colourControl(limitedToBroadband: false)

        case .modulatedBrown:
            NTParamRow(label: "Sweep rate", value: String(format: "%.2f Hz", config.modRate)) {
                NTSlider(value: Binding(get: { config.modRate },
                                        set: { v in onChange { $0.modRate = v } }),
                         range: 0.02...0.6, ticks: 6, tint: NTTheme.cyanDim)
            }
            NTParamRow(label: "Depth", value: String(format: "%.0f%%", config.modDepth * 100)) {
                NTSlider(value: Binding(get: { config.modDepth },
                                        set: { v in onChange { $0.modDepth = v } }),
                         range: 0...0.95, ticks: 5, tint: NTTheme.cyanDim)
            }
            NTParamRow(label: "Low-pass", value: NTNum.hz(config.cutoff)) {
                NTLogFreqSlider(frequency: Binding(get: { config.cutoff },
                                                   set: { v in onChange { $0.cutoff = v } }),
                                minHz: 200, maxHz: 6000)
            }

        case .fanBed:
            NTParamRow(label: "Low-pass corner", value: NTNum.hz(config.cutoff)) {
                NTLogFreqSlider(frequency: Binding(get: { config.cutoff },
                                                   set: { v in onChange { $0.cutoff = v } }),
                                minHz: 150, maxHz: 8000)
            }
            NTParamRow(label: "Wobble", value: String(format: "%.0f%%", config.modDepth * 100)) {
                NTSlider(value: Binding(get: { config.modDepth },
                                        set: { v in onChange { $0.modDepth = v } }),
                         range: 0...0.6, ticks: 6, tint: NTTheme.cyanDim)
            }

        case .rainBed:
            NTParamRow(label: "Centre", value: NTNum.hz(config.frequency)) {
                NTLogFreqSlider(frequency: Binding(get: { config.frequency },
                                                   set: { v in onChange { $0.frequency = v } }),
                                minHz: 400, maxHz: 9000)
            }
            NTInlineDisclaimer(text: "The pattering is a fast random envelope applied to band-passed noise, not a recording.")

        case .leavesBed:
            NTParamRow(label: "Low-pass corner", value: NTNum.hz(config.cutoff)) {
                NTLogFreqSlider(frequency: Binding(get: { config.cutoff },
                                                   set: { v in onChange { $0.cutoff = v } }),
                                minHz: 300, maxHz: 9000)
            }
            NTParamRow(label: "Comb depth", value: String(format: "%.0f%%", config.modDepth * 100)) {
                NTSlider(value: Binding(get: { config.modDepth },
                                        set: { v in onChange { $0.modDepth = v } }),
                         range: 0...1, ticks: 5, tint: NTTheme.cyanDim)
            }
            NTParamRow(label: "Rustle rate", value: String(format: "%.2f Hz", config.modRate)) {
                NTSlider(value: Binding(get: { config.modRate },
                                        set: { v in onChange { $0.modRate = v } }),
                         range: 0.03...0.8, ticks: 6, tint: NTTheme.cyanDim)
            }
        }
    }

    private func widthPicker(label: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(NTTheme.mono(9, .semibold))
                .foregroundColor(NTTheme.inkFaint)
                .tracking(1.0)
            HStack(spacing: 6) {
                ForEach(0..<NTOctave.choices.count, id: \.self) { i in
                    let v = NTOctave.choices[i]
                    Button(action: { set(v) }) {
                        Text(NTOctave.label(v))
                            .font(NTTheme.mono(11, .medium))
                            .foregroundColor(abs(v - value) < 0.01 ? NTTheme.deep : NTTheme.inkDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(abs(v - value) < 0.01 ? NTTheme.cyan : NTTheme.panelHigh)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func colourControl(limitedToBroadband: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOISE COLOUR")
                .font(NTTheme.mono(9, .semibold))
                .foregroundColor(NTTheme.inkFaint)
                .tracking(1.0)
            NTColourPicker(colour: Binding(get: { config.colour },
                                           set: { c in onChange { $0.colourRaw = c.rawValue } }))
            Text(config.colour.blurb)
                .font(NTTheme.rounded(11))
                .foregroundColor(NTTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Generator picker sheet

struct NTGeneratorPicker: View {
    @Binding var isPresented: Bool
    let profileFrequency: Double?
    let onPick: (NTLayerConfig) -> Void

    var body: some View {
        ZStack {
            NTTheme.deep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Add a generator")
                            .font(NTTheme.rounded(23, .bold))
                            .foregroundColor(NTTheme.ink)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            NTCrossGlyph(size: 18, color: NTTheme.inkDim)
                                .frame(width: 38, height: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    ForEach(NTGeneratorCatalogue.groups, id: \.self) { group in
                        let specs = NTGeneratorCatalogue.all.filter { $0.group == group }
                        if !specs.isEmpty {
                            NTSectionHeader(title: group)
                            ForEach(specs) { spec in
                                Button(action: {
                                    onPick(spec.makeDefault(profileFrequency))
                                    isPresented = false
                                }) {
                                    NTPanel(padding: 13) {
                                        VStack(alignment: .leading, spacing: 7) {
                                            HStack(spacing: 9) {
                                                NTBarsGlyph(size: 18, color: NTTheme.cyan,
                                                            heights: barsFor(spec.kind))
                                                Text(spec.title)
                                                    .font(NTTheme.rounded(15, .semibold))
                                                    .foregroundColor(NTTheme.ink)
                                                Spacer(minLength: 0)
                                                NTChevronGlyph(size: 15, color: NTTheme.cyan)
                                            }
                                            Text(spec.blurb)
                                                .font(NTTheme.rounded(12))
                                                .foregroundColor(NTTheme.inkDim)
                                                .lineSpacing(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 40)
            }
        }
    }

    private func barsFor(_ kind: NTGenKind) -> [CGFloat] {
        switch kind {
        case .notchedNoise: return [0.9, 0.85, 0.15, 0.85, 0.9]
        case .bandNoise: return [0.2, 0.55, 0.95, 0.55, 0.2]
        case .pureTone: return [0.1, 0.1, 1.0, 0.1, 0.1]
        case .colourNoise: return [0.95, 0.8, 0.65, 0.5, 0.35]
        case .modulatedBrown: return [1.0, 0.75, 0.5, 0.3, 0.18]
        case .fanBed: return [0.95, 0.85, 0.5, 0.22, 0.1]
        case .rainBed: return [0.3, 0.7, 0.45, 0.9, 0.55]
        case .leavesBed: return [0.4, 0.75, 0.4, 0.7, 0.45]
        }
    }
}

// MARK: - Save preset sheet

struct NTSavePresetSheet: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    let onSave: () -> Void

    var body: some View {
        ZStack {
            NTTheme.deep.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Save preset")
                        .font(NTTheme.rounded(23, .bold))
                        .foregroundColor(NTTheme.ink)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        NTCrossGlyph(size: 18, color: NTTheme.inkDim)
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("The current stack is saved exactly as it stands, including every parameter and level.")
                    .font(NTTheme.rounded(13))
                    .foregroundColor(NTTheme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $name)
                    .font(NTTheme.rounded(16))
                    .foregroundColor(NTTheme.ink)
                    .accentColor(NTTheme.cyan)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NTTheme.panelHigh))
                    .overlay(
                        HStack {
                            if name.isEmpty {
                                Text("Preset name")
                                    .font(NTTheme.rounded(16))
                                    .foregroundColor(NTTheme.inkFaint)
                                    .padding(.leading, 14)
                                    .allowsHitTesting(false)
                            }
                            Spacer()
                        }
                    )

                Button(action: {
                    onSave()
                    isPresented = false
                }) {
                    NTButtonLabel(title: "Save", filled: true, tint: NTTheme.cyan)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
        }
    }
}

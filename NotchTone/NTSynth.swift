import Foundation
import AVFoundation
import UIKit

// MARK: - Coefficient building (main thread)

enum NTCoeffBuilder {

    /// Perceptual trim so that switching generators does not jump in level.
    static func trim(for cfg: NTLayerConfig) -> Double {
        let colourTrim: Double
        switch cfg.colour {
        case .white: return kindTrim(cfg) * 0.55
        case .pink: colourTrim = 0.95
        case .brown: colourTrim = 0.62
        case .blue: colourTrim = 0.34
        case .violet: colourTrim = 0.24
        case .grey: colourTrim = 0.70
        }
        return kindTrim(cfg) * colourTrim
    }

    private static func kindTrim(_ cfg: NTLayerConfig) -> Double {
        switch cfg.kind {
        case .pureTone: return 0.30
        case .colourNoise: return 1.0
        case .notchedNoise: return 1.0
        case .bandNoise: return 2.6
        case .modulatedBrown: return 1.15
        case .fanBed: return 1.9
        case .rainBed: return 3.0
        case .leavesBed: return 1.5
        }
    }

    /// Turn a user-facing configuration into a flat parameter block for the audio thread.
    static func build(_ cfg: NTLayerConfig, gain: Double, sampleRate: Double) -> NTLayerParams {
        var p = NTLayerParams()
        p.enabled = cfg.enabled ? 1 : 0
        p.kind = cfg.kindRaw
        p.colour = cfg.colourRaw
        p.gain = NTNum.clamp(gain, 0, 1)
        p.trim = trim(for: cfg)

        let sr = max(8000, sampleRate)
        let nyq = sr * 0.45

        switch cfg.kind {
        case .pureTone:
            let f = NTNum.clamp(cfg.frequency, 40, min(14000, nyq))
            p.phaseInc = 2.0 * Double.pi * f / sr

        case .colourNoise:
            break

        case .notchedNoise:
            // Four cascaded band-reject sections give a deep, steep-sided notch.
            let f = NTNum.clamp(cfg.frequency, 120, min(12000, nyq))
            let q = NTFilterDesign.qForBandwidth(octaves: cfg.notchOctaves)
            // Slightly stagger the sections so the stop-band is flat-bottomed rather than a spike.
            let spread = pow(2.0, cfg.notchOctaves * 0.14)
            p.f0 = NTFilterDesign.notch(freq: f / spread, q: q * 1.3, sampleRate: sr)
            p.f1 = NTFilterDesign.notch(freq: f, q: q, sampleRate: sr)
            p.f2 = NTFilterDesign.notch(freq: f, q: q, sampleRate: sr)
            p.f3 = NTFilterDesign.notch(freq: f * spread, q: q * 1.3, sampleRate: sr)

        case .bandNoise:
            let f = NTNum.clamp(cfg.frequency, 100, min(12000, nyq))
            let q = max(0.4, NTFilterDesign.qForBandwidth(octaves: cfg.bandOctaves))
            p.f0 = NTFilterDesign.bandPass(freq: f, q: q, sampleRate: sr)
            p.f1 = NTFilterDesign.bandPass(freq: f, q: q, sampleRate: sr)

        case .modulatedBrown:
            p.colour = NTNoiseColour.brown.rawValue
            p.lfoInc = 2.0 * Double.pi * NTNum.clamp(cfg.modRate, 0.01, 2.0) / sr
            p.lfoDepth = NTNum.clamp(cfg.modDepth, 0, 0.95)
            p.f0 = NTFilterDesign.lowPass(freq: NTNum.clamp(cfg.cutoff, 200, 6000), q: 0.707, sampleRate: sr)

        case .fanBed:
            let c = NTNum.clamp(cfg.cutoff, 150, min(8000, nyq))
            p.f0 = NTFilterDesign.lowPass(freq: c, q: 0.707, sampleRate: sr)
            p.f1 = NTFilterDesign.lowPass(freq: c, q: 0.707, sampleRate: sr)
            p.f2 = NTFilterDesign.highPass(freq: 60, q: 0.707, sampleRate: sr)
            if cfg.modDepth > 0.01 {
                p.lfoInc = 2.0 * Double.pi * NTNum.clamp(cfg.modRate, 0.01, 2.0) / sr
                p.lfoDepth = NTNum.clamp(cfg.modDepth * 0.4, 0, 0.4)
            }

        case .rainBed:
            let f = NTNum.clamp(cfg.frequency, 400, min(9000, nyq))
            p.f0 = NTFilterDesign.bandPass(freq: f, q: 0.55, sampleRate: sr)
            p.f1 = NTFilterDesign.highPass(freq: 300, q: 0.707, sampleRate: sr)
            p.envRate = NTNum.clamp(220.0 / sr, 0.0005, 0.05)

        case .leavesBed:
            let c = NTNum.clamp(cfg.cutoff, 300, min(9000, nyq))
            p.f0 = NTFilterDesign.lowPass(freq: c, q: 0.707, sampleRate: sr)
            p.f1 = NTFilterDesign.highPass(freq: 180, q: 0.707, sampleRate: sr)
            // A short comb gives a dry rustle without any sample material.
            let delaySec = 0.0032 + 0.0045 * NTNum.clamp(cfg.modDepth, 0, 1)
            p.combDelay = Int32(NTNum.clamp(delaySec * sr, 8, Double(NTMaxCombDelay - 2)))
            p.combMix = 0.45
            p.lfoInc = 2.0 * Double.pi * NTNum.clamp(cfg.modRate, 0.01, 2.0) / sr
            p.lfoDepth = NTNum.clamp(cfg.modDepth * 0.5, 0, 0.5)
        }

        if cfg.colour == .grey {
            // White shaped by a coarse inverse of the ear's sensitivity curve, so the
            // result sounds more even across the range than plain white noise.
            p.g0 = NTFilterDesign.peaking(freq: 130, q: 0.60, gainDb: 11, sampleRate: sr)
            p.g1 = NTFilterDesign.peaking(freq: 3400, q: 0.85, gainDb: -8, sampleRate: sr)
            p.g2 = NTFilterDesign.peaking(freq: 9500, q: 0.70, gainDb: 7, sampleRate: sr)
        }

        return p
    }
}

// MARK: - Render helper (audio thread)
//
// A top-level, non-generic, non-escaping function taking raw pointers. It performs no
// allocation, takes no lock, and calls nothing that could touch the Swift runtime.

@inline(__always)
private func ntRenderLayer(_ p: UnsafeMutablePointer<NTLayerParams>,
                           _ s: UnsafeMutablePointer<NTLayerState>,
                           _ comb: UnsafeMutablePointer<Double>,
                           _ smooth: Double) -> Double {

    let target = p.pointee.enabled != 0 ? p.pointee.gain : 0.0
    s.pointee.currentGain += (target - s.pointee.currentGain) * smooth
    let g = s.pointee.currentGain
    if g < 0.000005 && target == 0 { return 0 }

    var out: Double

    if p.pointee.kind == NTGenKind.pureTone.rawValue {
        var ph = s.pointee.phase + p.pointee.phaseInc
        if ph >= 6.283185307179586 { ph -= 6.283185307179586 }
        s.pointee.phase = ph
        out = sin(ph)
    } else {
        let w = s.pointee.rng.white()
        switch p.pointee.colour {
        case 1:
            out = s.pointee.pink.process(w)
        case 2:
            out = s.pointee.brown.process(w)
        case 3:
            out = s.pointee.diffA.process(s.pointee.pink.process(w)) * 3.0
        case 4:
            out = s.pointee.diffB.process(w) * 0.55
        case 5:
            var v = w
            v = ntProcess(p.pointee.g0, &s.pointee.zg0, v)
            v = ntProcess(p.pointee.g1, &s.pointee.zg1, v)
            v = ntProcess(p.pointee.g2, &s.pointee.zg2, v)
            out = v * 0.55
        default:
            out = w
        }

        switch p.pointee.kind {
        case 2: // notched noise — four cascaded band-reject sections
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
            out = ntProcess(p.pointee.f1, &s.pointee.z1, out)
            out = ntProcess(p.pointee.f2, &s.pointee.z2, out)
            out = ntProcess(p.pointee.f3, &s.pointee.z3, out)
        case 3: // band-limited noise
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
            out = ntProcess(p.pointee.f1, &s.pointee.z1, out)
        case 4: // amplitude-modulated brown
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
        case 5: // fan bed
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
            out = ntProcess(p.pointee.f1, &s.pointee.z1, out)
            out = ntProcess(p.pointee.f2, &s.pointee.z2, out)
        case 6: // rain bed
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
            out = ntProcess(p.pointee.f1, &s.pointee.z1, out)
            let rate = p.pointee.envRate
            if rate > 0 {
                if s.pointee.rng.unit() < rate * 0.35 {
                    s.pointee.envTarget = 0.20 + 0.80 * s.pointee.rng.unit()
                }
                s.pointee.envValue += (s.pointee.envTarget - s.pointee.envValue) * rate
                out *= s.pointee.envValue
            }
        case 7: // leaves bed — low-passed noise through a short comb
            out = ntProcess(p.pointee.f0, &s.pointee.z0, out)
            out = ntProcess(p.pointee.f1, &s.pointee.z1, out)
            let d = Int(p.pointee.combDelay)
            if d > 1 && d < NTMaxCombDelay {
                let idx = Int(s.pointee.combIndex)
                var readIdx = idx - d
                if readIdx < 0 { readIdx += NTMaxCombDelay }
                let delayed = comb[readIdx]
                let written = out + delayed * p.pointee.combMix
                comb[idx] = written
                var nextIdx = idx + 1
                if nextIdx >= NTMaxCombDelay { nextIdx = 0 }
                s.pointee.combIndex = Int32(nextIdx)
                out = (out + delayed) * 0.6
            }
        default:
            break
        }
    }

    let depth = p.pointee.lfoDepth
    if depth > 0.0001 {
        var lp = s.pointee.lfoPhase + p.pointee.lfoInc
        if lp >= 6.283185307179586 { lp -= 6.283185307179586 }
        s.pointee.lfoPhase = lp
        let mod = (1.0 - depth) + depth * (0.5 + 0.5 * sin(lp))
        out *= mod
    }

    return out * p.pointee.trim * g
}

// MARK: - The engine

final class NTSynth: NSObject, ObservableObject {

    static let maxLayers = 3

    // Published UI state
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var isFadingOut: Bool = false
    @Published private(set) var engineFailed: Bool = false
    @Published var layers: [NTLayerConfig] = []
    @Published var masterLevel: Double = 0.45
    @Published var timerMinutes: Int = 45
    @Published private(set) var inMeasurementMode: Bool = false

    /// Hard ceiling on the synthesiser's own amplitude, set from Settings.
    var outputCap: Double = 0.32
    /// Ramp-in time constant, seconds.
    var fadeSeconds: Double = 0.3
    /// Slow fade at the end of a timed session, seconds.
    var endFadeSeconds: Double = 60
    var allowBackground: Bool = true

    /// Called when a playback session of meaningful length finishes.
    var onSessionFinished: ((NTSessionLog) -> Void)?
    /// Called whenever the user's own generator stack changes, so it can be persisted.
    /// Never fires while a measurement procedure is borrowing the engine.
    var onStackChanged: (([NTLayerConfig]) -> Void)?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var sampleRate: Double = 48000

    private let paramsPtr: UnsafeMutablePointer<NTLayerParams>
    private let statePtr: UnsafeMutablePointer<NTLayerState>
    private let combPtr: UnsafeMutablePointer<Double>
    private let masterPtr: UnsafeMutablePointer<NTMasterParams>
    private let masterStatePtr: UnsafeMutablePointer<Double>
    private let levelPtr: UnsafeMutablePointer<Double>

    private var tickTimer: Timer?
    private var sessionStart: Date?
    private var wasPlayingBeforeInterruption = false
    private var savedLayers: [NTLayerConfig] = []
    private var fadeMultiplier: Double = 1.0
    private var engineConfigured = false

    override init() {
        paramsPtr = UnsafeMutablePointer<NTLayerParams>.allocate(capacity: NTSynth.maxLayers)
        statePtr = UnsafeMutablePointer<NTLayerState>.allocate(capacity: NTSynth.maxLayers)
        combPtr = UnsafeMutablePointer<Double>.allocate(capacity: NTMaxCombDelay * NTSynth.maxLayers)
        masterPtr = UnsafeMutablePointer<NTMasterParams>.allocate(capacity: 1)
        masterStatePtr = UnsafeMutablePointer<Double>.allocate(capacity: 1)
        levelPtr = UnsafeMutablePointer<Double>.allocate(capacity: 1)

        for i in 0..<NTSynth.maxLayers {
            paramsPtr.advanced(by: i).initialize(to: NTLayerParams())
            var st = NTLayerState()
            st.rng = NTRandom(state: UInt32(truncatingIfNeeded: 0x1F35_3D17 &+ (i &* 0x2545_F491)))
            statePtr.advanced(by: i).initialize(to: st)
        }
        combPtr.initialize(repeating: 0, count: NTMaxCombDelay * NTSynth.maxLayers)
        masterPtr.initialize(to: NTMasterParams())
        masterStatePtr.initialize(to: 0)
        levelPtr.initialize(to: 0)

        super.init()
        registerObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        tickTimer?.invalidate()
        paramsPtr.deinitialize(count: NTSynth.maxLayers)
        statePtr.deinitialize(count: NTSynth.maxLayers)
        combPtr.deinitialize(count: NTMaxCombDelay * NTSynth.maxLayers)
        masterPtr.deinitialize(count: 1)
        masterStatePtr.deinitialize(count: 1)
        levelPtr.deinitialize(count: 1)
        paramsPtr.deallocate()
        statePtr.deallocate()
        combPtr.deallocate()
        masterPtr.deallocate()
        masterStatePtr.deallocate()
        levelPtr.deallocate()
    }

    // MARK: Session

    private func activateSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setPreferredSampleRate(48000)
            try session.setActive(true, options: [])
            return true
        } catch {
            return false
        }
    }

    private func deactivateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: Engine setup

    private func configureEngineIfNeeded() {
        guard !engineConfigured else { return }
        let rate = AVAudioSession.sharedInstance().sampleRate
        sampleRate = rate > 8000 ? rate : 48000

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            engineFailed = true
            return
        }

        let params = paramsPtr
        let states = statePtr
        let comb = combPtr
        let master = masterPtr
        let masterState = masterStatePtr
        let level = levelPtr
        let smooth = NTNum.clamp(1.0 - exp(-1.0 / (max(0.02, fadeSeconds) * sampleRate)), 0.000001, 0.5)

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            let running = master.pointee.running != 0
            let mTarget = running ? master.pointee.gain : 0.0
            let mSmooth = master.pointee.smoothing
            let panL = master.pointee.panL
            let panR = master.pointee.panR
            var peak: Double = 0

            // Channel pointers are resolved once per block, never per sample.
            var ch0: UnsafeMutablePointer<Float>? = nil
            var ch1: UnsafeMutablePointer<Float>? = nil
            if abl.count > 0, let d = abl[0].mData { ch0 = d.assumingMemoryBound(to: Float.self) }
            if abl.count > 1, let d = abl[1].mData { ch1 = d.assumingMemoryBound(to: Float.self) }

            for frame in 0..<frames {
                var mix: Double = 0
                mix += ntRenderLayer(params, states, comb, smooth)
                mix += ntRenderLayer(params.advanced(by: 1), states.advanced(by: 1),
                                     comb.advanced(by: NTMaxCombDelay), smooth)
                mix += ntRenderLayer(params.advanced(by: 2), states.advanced(by: 2),
                                     comb.advanced(by: NTMaxCombDelay * 2), smooth)

                var mg = masterState.pointee
                mg += (mTarget - mg) * mSmooth
                masterState.pointee = mg

                // Limit the SUM first, then apply the master gain. Ordering matters:
                // ntSoftLimit saturates at 2/3, so |sample| <= (2/3) * mg <= (2/3) * outputCap
                // and the Settings ceiling is a real ceiling for any number of layers at any
                // level. Limiting after the gain (ntSoftLimit(mix * mg)) let three layers at
                // 1.0 reach ~0.49 against a 0.32 cap, which made the Settings copy untrue.
                let sample = ntSoftLimit(mix) * mg
                if sample > peak { peak = sample } else if -sample > peak { peak = -sample }

                ch0?[frame] = Float(sample * panL)
                ch1?[frame] = Float(sample * panR)
            }

            let prev = level.pointee
            level.pointee = peak > prev ? peak : prev * 0.85 + peak * 0.15
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        sourceNode = node
        engineConfigured = true

        masterPtr.pointee.smoothing = NTNum.clamp(1.0 - exp(-1.0 / (max(0.02, fadeSeconds) * sampleRate)), 0.000001, 0.5)
    }

    private func teardownEngine() {
        if engine.isRunning { engine.stop() }
        if let node = sourceNode {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        sourceNode = nil
        engineConfigured = false
        masterStatePtr.pointee = 0
        // Nothing can be playing through an engine that no longer exists. Leaving this
        // set would strand every transport control in its "playing" state.
        isPlaying = false
    }

    // MARK: Parameter publishing

    /// Recompute every coefficient on the main thread and copy the flat blocks across.
    func publishLayers() {
        let sr = sampleRate
        for i in 0..<NTSynth.maxLayers {
            if i < layers.count {
                let cfg = layers[i]
                paramsPtr.advanced(by: i).pointee =
                    NTCoeffBuilder.build(cfg, gain: NTNum.clamp(cfg.level, 0, 1), sampleRate: sr)
            } else {
                var off = NTLayerParams()
                off.enabled = 0
                off.gain = 0
                paramsPtr.advanced(by: i).pointee = off
            }
        }
        publishMaster()
        if !inMeasurementMode { onStackChanged?(layers) }
    }

    func publishMaster() {
        let level = NTNum.clamp(masterLevel, 0, 1)
        let cap = NTNum.clamp(outputCap, 0.02, 0.60)
        // Perceptual taper: a squared curve gives finer control at quiet settings,
        // which is where a tinnitus sound should live.
        let taper = level * level * 0.85 + level * 0.15
        masterPtr.pointee.gain = NTNum.clamp(cap * taper * fadeMultiplier, 0, cap)
    }

    // MARK: Transport

    func play() {
        guard !layers.isEmpty else { return }
        guard activateSession() else { engineFailed = true; return }
        configureEngineIfNeeded()
        guard engineConfigured else { return }

        // The sound stack always plays to both ears; only measurements use one side.
        setEar(.both)
        // Start from silence so the ramp-in is always audible as a fade, never a click.
        if !isPlaying { masterStatePtr.pointee = 0 }

        // Only a genuinely new session arms the sleep timer. Resuming a paused one must
        // keep the clock where it was, or pausing to answer the door would silently hand
        // the listener a whole fresh timer's worth of sound.
        if sessionStart == nil {
            sessionStart = Date()
            elapsedSeconds = 0
            remainingSeconds = timerMinutes > 0 ? timerMinutes * 60 : 0
        } else if timerMinutes <= 0 {
            remainingSeconds = 0
        } else if remainingSeconds <= 0 {
            remainingSeconds = timerMinutes * 60
        }
        // Resuming inside the closing fade keeps the level the fade had reached, so the
        // last minute of a session never jumps back up to full.
        applyFadeForRemaining()

        // Pick up any change to the fade setting made since the engine was configured.
        masterPtr.pointee.smoothing =
            NTNum.clamp(1.0 - exp(-1.0 / (max(0.02, fadeSeconds) * sampleRate)), 0.000001, 0.5)
        publishLayers()
        masterPtr.pointee.running = 1

        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            engineFailed = true
            masterPtr.pointee.running = 0
            return
        }

        engineFailed = false
        isPlaying = true
        markRunReference()
        startTicking()
    }

    /// Derive the closing-fade state from the seconds still on the clock. Used both when
    /// starting or resuming and on every tick, so the two can never disagree.
    private func applyFadeForRemaining() {
        guard timerMinutes > 0 else {
            isFadingOut = false
            fadeMultiplier = 1.0
            return
        }
        let fadeWindow = max(5.0, endFadeSeconds)
        if Double(remainingSeconds) <= fadeWindow {
            isFadingOut = true
            fadeMultiplier = NTNum.clamp(Double(remainingSeconds) / fadeWindow, 0, 1)
        } else {
            isFadingOut = false
            fadeMultiplier = 1.0
        }
    }

    func pause() {
        guard isPlaying else { return }
        masterPtr.pointee.running = 0
        isPlaying = false
        isFadingOut = false
        stopTicking()
        // The counters keep their values; the next play() re-bases the clock on them.
        runStart = nil
        // Give the smoothing a moment to reach zero before halting the engine,
        // so pausing never produces a click.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.25, fadeSeconds * 2)) { [weak self] in
            guard let self = self else { return }
            if !self.isPlaying && self.engine.isRunning {
                self.engine.pause()
            }
        }
    }

    func stop(logSession: Bool = true) {
        let wasPlaying = isPlaying
        masterPtr.pointee.running = 0
        isPlaying = false
        isFadingOut = false
        stopTicking()
        fadeMultiplier = 1.0
        publishMaster()

        let start = sessionStart
        let seconds = elapsedSeconds
        sessionStart = nil
        runStart = nil
        elapsedSeconds = 0
        remainingSeconds = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.25, fadeSeconds * 2)) { [weak self] in
            guard let self = self else { return }
            if !self.isPlaying {
                self.teardownEngine()
                self.deactivateSession()
            }
        }

        if logSession, wasPlaying, seconds >= 20, let s = start {
            let summary = layers.filter { $0.enabled }.map { $0.displayName }.joined(separator: " + ")
            onSessionFinished?(NTSessionLog(startedAt: s, seconds: seconds,
                                            summary: summary.isEmpty ? "Silent stack" : summary))
        }
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    /// Present sound to one ear or to both. Used by the measurement screens.
    func setEar(_ ear: NTEar) {
        switch ear {
        case .both:
            masterPtr.pointee.panL = 1
            masterPtr.pointee.panR = 1
        case .left:
            masterPtr.pointee.panL = 1
            masterPtr.pointee.panR = 0
        case .right:
            masterPtr.pointee.panL = 0
            masterPtr.pointee.panR = 1
        }
    }

    /// Change the sleep timer without interrupting playback.
    func setTimer(minutes: Int) {
        timerMinutes = minutes
        remainingSeconds = minutes > 0 ? minutes * 60 : 0
        if isPlaying { markRunReference() }
        applyFadeForRemaining()
        publishMaster()
    }

    // MARK: Ticking

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// Wall-clock reference for the run currently in progress, together with the two
    /// counters as they stood when it began. Counting timer fires would let any run-loop
    /// delay silently stretch a session and its sleep timer; reading the clock cannot drift.
    private var runStart: Date?
    private var elapsedAtRunStart: Int = 0
    private var remainingAtRunStart: Int = 0

    /// Re-base the clock reference on the counters as they stand right now. Called when
    /// playback starts or resumes and when the sleep timer is changed mid-session, so
    /// time spent paused is never billed to the session or to the timer.
    private func markRunReference() {
        runStart = Date()
        elapsedAtRunStart = elapsedSeconds
        remainingAtRunStart = remainingSeconds
    }

    private func tick() {
        guard isPlaying, let reference = runStart else { return }
        let run = max(0, Int(Date().timeIntervalSince(reference)))

        let elapsed = elapsedAtRunStart + run
        if elapsed != elapsedSeconds { elapsedSeconds = elapsed }

        if timerMinutes > 0 {
            let remaining = max(0, remainingAtRunStart - run)
            if remaining != remainingSeconds { remainingSeconds = remaining }
            let wasFading = isFadingOut
            applyFadeForRemaining()
            if isFadingOut || wasFading { publishMaster() }
            if remainingSeconds <= 0 {
                stop()
            }
        }
    }

    // MARK: Measurement mode
    //
    // The measurement screens borrow the engine but must never disturb the user's
    // carefully built sound stack, so it is saved and restored around them.

    func beginMeasurementMode() {
        guard !inMeasurementMode else { return }
        if isPlaying { stop(logSession: true) }
        savedLayers = layers
        inMeasurementMode = true
        layers = []
        for i in 0..<NTSynth.maxLayers {
            var off = NTLayerParams()
            off.enabled = 0
            paramsPtr.advanced(by: i).pointee = off
        }
    }

    func endMeasurementMode() {
        guard inMeasurementMode else { return }
        stopMeasurementTone()
        setEar(.both)
        layers = savedLayers
        savedLayers = []
        inMeasurementMode = false
        publishLayers()
        // Hand the audio session back so other apps are not left silenced.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            if !self.isPlaying {
                self.teardownEngine()
                self.deactivateSession()
            }
        }
    }

    /// Play a single calibrated-in-app-units voice for a measurement procedure.
    /// `attenuationDb` is negative decibels relative to the app's own reference level.
    func playMeasurement(_ cfg: NTLayerConfig, attenuationDb: Double) {
        guard activateSession() else { engineFailed = true; return }
        configureEngineIfNeeded()
        guard engineConfigured else { return }

        let amp = NTNum.clamp(pow(10.0, NTNum.clamp(attenuationDb, -90, 0) / 20.0), 0, 1)
        var built = NTCoeffBuilder.build(cfg, gain: amp, sampleRate: sampleRate)
        // Measurements bypass the perceptual trim so that 0 dB means exactly the app's
        // own output ceiling. Every recorded figure is relative to that one definition.
        built.trim = 1.0
        built.enabled = 1
        paramsPtr.pointee = built
        for i in 1..<NTSynth.maxLayers {
            var off = NTLayerParams()
            off.enabled = 0
            paramsPtr.advanced(by: i).pointee = off
        }

        fadeMultiplier = 1.0
        masterPtr.pointee.gain = NTNum.clamp(outputCap, 0.02, 0.60)
        masterPtr.pointee.running = 1

        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            engineFailed = true
            masterPtr.pointee.running = 0
            return
        }
        engineFailed = false
        isPlaying = true
    }

    /// Update the measurement voice without restarting it, so a dial stays smooth.
    func updateMeasurement(_ cfg: NTLayerConfig, attenuationDb: Double) {
        guard engineConfigured else { return }
        let amp = NTNum.clamp(pow(10.0, NTNum.clamp(attenuationDb, -90, 0) / 20.0), 0, 1)
        var built = NTCoeffBuilder.build(cfg, gain: amp, sampleRate: sampleRate)
        built.trim = 1.0
        built.enabled = 1
        paramsPtr.pointee = built
    }

    func stopMeasurementTone() {
        paramsPtr.pointee.enabled = 0
        masterPtr.pointee.running = 0
        isPlaying = false
        // `fadeSeconds` is the time CONSTANT of a one-pole decay, so the signal is still
        // at about 26% after 1.3 constants. Five of them is inaudible; pausing earlier
        // truncates the tail on a step.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1.5, fadeSeconds * 5)) { [weak self] in
            guard let self = self else { return }
            if !self.isPlaying && self.engine.isRunning {
                self.engine.pause()
            }
        }
    }

    // MARK: Metering

    /// Smoothed peak level of the last render block as a fraction of the app's own output
    /// ceiling, 0 - 1. The raw amplitude can never exceed `outputCap`, so a meter fed the
    /// raw value would sit in its bottom third for ever; this is what the display wants.
    var meterLevel: Double {
        let v = levelPtr.pointee
        guard v.isFinite else { return 0 }
        let cap = NTNum.clamp(outputCap, 0.02, 0.60)
        return NTNum.clamp(NTNum.safeDiv(v, cap), 0, 1)
    }

    // MARK: Layer editing helpers

    func setLayers(_ new: [NTLayerConfig]) {
        layers = Array(new.prefix(NTSynth.maxLayers))
        publishLayers()
    }

    func updateLayer(_ index: Int, _ mutate: (inout NTLayerConfig) -> Void) {
        guard index >= 0 && index < layers.count else { return }
        var cfg = layers[index]
        mutate(&cfg)
        layers[index] = cfg
        publishLayers()
    }

    func addLayer(_ cfg: NTLayerConfig) {
        guard layers.count < NTSynth.maxLayers else { return }
        layers.append(cfg)
        publishLayers()
    }

    func removeLayer(at index: Int) {
        guard index >= 0 && index < layers.count else { return }
        layers.remove(at: index)
        publishLayers()
        if layers.isEmpty && isPlaying { stop() }
    }

    // MARK: Notifications

    private func registerObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleMediaReset(_:)),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleBackground(_:)),
                       name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        // AVAudioSession posts on an arbitrary queue; all published state lives on main.
        DispatchQueue.main.async { [weak self] in self?.applyInterruption(note) }
    }

    private func applyInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                masterPtr.pointee.running = 0
                isPlaying = false
                stopTicking()
                if engine.isRunning { engine.pause() }
            }
        case .ended:
            var shouldResume = false
            if let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume)
            }
            if wasPlayingBeforeInterruption && shouldResume && !inMeasurementMode {
                play()
            } else if wasPlayingBeforeInterruption {
                // Leave the engine stopped but keep the session state tidy.
                masterPtr.pointee.running = 0
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in self?.applyRouteChange(note) }
    }

    private func applyRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones pulled out: pause, exactly as users expect.
            if isPlaying {
                if inMeasurementMode { stopMeasurementTone() } else { pause() }
            }
        case .newDeviceAvailable, .override, .categoryChange:
            let newRate = AVAudioSession.sharedInstance().sampleRate
            if newRate > 8000 && abs(newRate - sampleRate) > 1 {
                let wasPlaying = isPlaying
                let saved = layers
                teardownEngine()
                sampleRate = newRate
                if wasPlaying && !inMeasurementMode {
                    layers = saved
                    play()
                } else if wasPlaying {
                    // A measurement voice is never restarted behind the user's back;
                    // tear it down properly so the procedure screen can recover.
                    stopMeasurementTone()
                }
            }
        default:
            break
        }
    }

    @objc private func handleMediaReset(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in self?.applyMediaReset() }
    }

    private func applyMediaReset() {
        let wasPlaying = isPlaying
        teardownEngine()
        masterPtr.pointee.running = 0
        isPlaying = false
        if wasPlaying && !inMeasurementMode {
            play()
        }
    }

    @objc private func handleBackground(_ note: Notification) {
        if inMeasurementMode {
            stopMeasurementTone()
            return
        }
        if isPlaying && !allowBackground {
            stop()
        }
    }
}

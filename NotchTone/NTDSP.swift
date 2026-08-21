import Foundation

// MARK: - Notch Tone DSP primitives
//
// Everything in this file is designed to run inside a real-time audio render callback:
// plain value types, no classes, no allocation, no locking, no Swift runtime calls that
// could take a lock. Coefficients are always computed on the main thread (see NTSynth)
// and copied across as plain structs.

// MARK: Biquad

/// Coefficients only. Normalised so a0 == 1.
struct NTCoeffs {
    var b0: Double = 1
    var b1: Double = 0
    var b2: Double = 0
    var a1: Double = 0
    var a2: Double = 0

    static let bypass = NTCoeffs()
}

/// Delay memory only, kept separate from coefficients so that re-tuning a filter
/// mid-playback never zeroes its state (which would produce an audible click).
struct NTZ {
    var z1: Double = 0
    var z2: Double = 0
}

/// Transposed direct form II. Numerically well-behaved and cheap.
@inline(__always)
func ntProcess(_ c: NTCoeffs, _ z: inout NTZ, _ x: Double) -> Double {
    let y = c.b0 * x + z.z1
    z.z1 = c.b1 * x - c.a1 * y + z.z2
    z.z2 = c.b2 * x - c.a2 * y
    return y
}

// MARK: Coefficient design (main thread only)

enum NTFilterDesign {

    /// RBJ band-reject ("notch"). This is the filter the app is named after.
    static func notch(freq: Double, q: Double, sampleRate: Double) -> NTCoeffs {
        let f = NTNum.clamp(freq, 20, sampleRate * 0.45)
        let qq = NTNum.clamp(q, 0.05, 40)
        let w0 = 2.0 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2.0 * qq)
        let a0 = 1 + alpha
        guard a0 != 0 else { return .bypass }
        return NTCoeffs(b0: 1 / a0,
                        b1: (-2 * cw) / a0,
                        b2: 1 / a0,
                        a1: (-2 * cw) / a0,
                        a2: (1 - alpha) / a0)
    }

    /// RBJ constant-skirt band-pass, normalised to unity peak gain.
    static func bandPass(freq: Double, q: Double, sampleRate: Double) -> NTCoeffs {
        let f = NTNum.clamp(freq, 20, sampleRate * 0.45)
        let qq = NTNum.clamp(q, 0.05, 40)
        let w0 = 2.0 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2.0 * qq)
        let a0 = 1 + alpha
        guard a0 != 0 else { return .bypass }
        return NTCoeffs(b0: alpha / a0,
                        b1: 0,
                        b2: -alpha / a0,
                        a1: (-2 * cw) / a0,
                        a2: (1 - alpha) / a0)
    }

    static func lowPass(freq: Double, q: Double, sampleRate: Double) -> NTCoeffs {
        let f = NTNum.clamp(freq, 20, sampleRate * 0.45)
        let qq = NTNum.clamp(q, 0.05, 40)
        let w0 = 2.0 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2.0 * qq)
        let a0 = 1 + alpha
        guard a0 != 0 else { return .bypass }
        return NTCoeffs(b0: ((1 - cw) / 2) / a0,
                        b1: (1 - cw) / a0,
                        b2: ((1 - cw) / 2) / a0,
                        a1: (-2 * cw) / a0,
                        a2: (1 - alpha) / a0)
    }

    static func highPass(freq: Double, q: Double, sampleRate: Double) -> NTCoeffs {
        let f = NTNum.clamp(freq, 10, sampleRate * 0.45)
        let qq = NTNum.clamp(q, 0.05, 40)
        let w0 = 2.0 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2.0 * qq)
        let a0 = 1 + alpha
        guard a0 != 0 else { return .bypass }
        return NTCoeffs(b0: ((1 + cw) / 2) / a0,
                        b1: (-(1 + cw)) / a0,
                        b2: ((1 + cw) / 2) / a0,
                        a1: (-2 * cw) / a0,
                        a2: (1 - alpha) / a0)
    }

    static func peaking(freq: Double, q: Double, gainDb: Double, sampleRate: Double) -> NTCoeffs {
        let f = NTNum.clamp(freq, 20, sampleRate * 0.45)
        let qq = NTNum.clamp(q, 0.05, 40)
        let A = pow(10.0, gainDb / 40.0)
        let w0 = 2.0 * Double.pi * f / sampleRate
        let cw = cos(w0), sw = sin(w0)
        let alpha = sw / (2.0 * qq)
        let a0 = 1 + alpha / A
        guard a0 != 0 else { return .bypass }
        return NTCoeffs(b0: (1 + alpha * A) / a0,
                        b1: (-2 * cw) / a0,
                        b2: (1 - alpha * A) / a0,
                        a1: (-2 * cw) / a0,
                        a2: (1 - alpha / A) / a0)
    }

    /// Magnitude response of one biquad at a frequency — used by the Canvas spectrum view
    /// so the drawing shows the real filter, not a hand-waved curve.
    static func magnitude(_ c: NTCoeffs, freq: Double, sampleRate: Double) -> Double {
        let w = 2.0 * Double.pi * NTNum.clamp(freq, 1, sampleRate * 0.5) / sampleRate
        let cw = cos(w), c2w = cos(2 * w)
        let sw = sin(w), s2w = sin(2 * w)
        let numRe = c.b0 + c.b1 * cw + c.b2 * c2w
        let numIm = -(c.b1 * sw + c.b2 * s2w)
        let denRe = 1 + c.a1 * cw + c.a2 * c2w
        let denIm = -(c.a1 * sw + c.a2 * s2w)
        let num = sqrt(numRe * numRe + numIm * numIm)
        let den = sqrt(denRe * denRe + denIm * denIm)
        return NTNum.safeDiv(num, den, fallback: 0)
    }

    /// Q that produces a band-reject of the requested width in octaves (RBJ bandwidth form).
    static func qForBandwidth(octaves: Double) -> Double {
        let bw = NTNum.clamp(octaves, 0.05, 6)
        let ln2over2 = 0.34657359027997264 // ln(2)/2
        let x = ln2over2 * bw
        let sh = sinh(x)
        guard sh > 0.0000001 else { return 20 }
        // Standard relation: 1/Q = 2*sinh(ln2/2 * BW) — approximately, at w0 << pi.
        return NTNum.clamp(1.0 / (2.0 * sh), 0.05, 40)
    }
}

// MARK: Random

/// xorshift32 — deterministic, branch-free, and allocation-free.
struct NTRandom {
    var state: UInt32 = 0x9E3779B9

    @inline(__always)
    mutating func next() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x == 0 ? 0x9E3779B9 : x
        return state
    }

    /// Uniform white noise in [-1, 1).
    @inline(__always)
    mutating func white() -> Double {
        let v = Double(next() >> 8) * (1.0 / 8388608.0) // 0 ..< 2
        return v - 1.0
    }

    @inline(__always)
    mutating func unit() -> Double {
        Double(next() >> 8) * (1.0 / 16777216.0)
    }
}

// MARK: Noise colour state

/// Paul Kellet's refined pink-noise filter: a seven-pole IIR chain giving a
/// genuine -3 dB/octave slope. This is not scaled white noise.
struct NTPinkState {
    var b0: Double = 0, b1: Double = 0, b2: Double = 0
    var b3: Double = 0, b4: Double = 0, b5: Double = 0, b6: Double = 0

    @inline(__always)
    mutating func process(_ white: Double) -> Double {
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        return out * 0.15
    }
}

/// Leaky integrator: a true -6 dB/octave brown (red) slope.
struct NTBrownState {
    var last: Double = 0

    @inline(__always)
    mutating func process(_ white: Double) -> Double {
        last = (last + 0.02 * white) / 1.02
        return last * 3.2
    }
}

/// One-sample differentiator, used to build blue (+3) from pink and violet (+6) from white.
struct NTDiffState {
    var last: Double = 0

    @inline(__always)
    mutating func process(_ x: Double) -> Double {
        let out = x - last
        last = x
        return out
    }
}

// MARK: Layer kinds

enum NTGenKind: Int32 {
    case pureTone = 0
    case colourNoise = 1
    case notchedNoise = 2
    case bandNoise = 3
    case modulatedBrown = 4
    case fanBed = 5
    case rainBed = 6
    case leavesBed = 7
}

enum NTNoiseColour: Int32, CaseIterable {
    case white = 0
    case pink = 1
    case brown = 2
    case blue = 3
    case violet = 4
    case grey = 5

    var title: String {
        switch self {
        case .white: return "White"
        case .pink: return "Pink"
        case .brown: return "Brown"
        case .blue: return "Blue"
        case .violet: return "Violet"
        case .grey: return "Grey"
        }
    }

    var slopeLabel: String {
        switch self {
        case .white: return "0 dB/oct"
        case .pink: return "-3 dB/oct"
        case .brown: return "-6 dB/oct"
        case .blue: return "+3 dB/oct"
        case .violet: return "+6 dB/oct"
        case .grey: return "loudness shaped"
        }
    }

    var blurb: String {
        switch self {
        case .white: return "Equal energy per hertz. Bright and hissy; the reference against which the others are described."
        case .pink: return "Energy falls by three decibels each octave, which many people describe as balanced or natural."
        case .brown: return "Falls by six decibels each octave. Deep and rumbling, close to distant surf or a large waterfall."
        case .blue: return "Rises by three decibels each octave. Thin and airy; some people find high-frequency emphasis less comfortable."
        case .violet: return "Rises by six decibels each octave. Very bright. Start extremely quiet with this one."
        case .grey: return "White noise shaped by an approximate inverse of the ear's sensitivity curve, so it sounds more even across the range."
        }
    }

    /// dB/octave slope used by the drawn spectrum.
    var slopePerOctave: Double {
        switch self {
        case .white: return 0
        case .pink: return -3
        case .brown: return -6
        case .blue: return 3
        case .violet: return 6
        case .grey: return 0
        }
    }
}

// MARK: Per-layer parameter block (written by main thread, read by audio thread)

struct NTLayerParams {
    var enabled: Int32 = 0
    var kind: Int32 = NTGenKind.colourNoise.rawValue
    var colour: Int32 = NTNoiseColour.pink.rawValue
    var gain: Double = 0

    // Pure tone
    var phaseInc: Double = 0

    // Amplitude modulation
    var lfoInc: Double = 0
    var lfoDepth: Double = 0

    // Main filter cascade (meaning depends on `kind`)
    var f0: NTCoeffs = .bypass
    var f1: NTCoeffs = .bypass
    var f2: NTCoeffs = .bypass
    var f3: NTCoeffs = .bypass

    // Colour-shaping cascade (grey noise)
    var g0: NTCoeffs = .bypass
    var g1: NTCoeffs = .bypass
    var g2: NTCoeffs = .bypass

    // Post trim so every generator lands at a comparable perceived level
    var trim: Double = 1

    // Rain envelope: how fast the random amplitude envelope moves, 0..1 per sample
    var envRate: Double = 0

    // Comb (leaves)
    var combDelay: Int32 = 0
    var combMix: Double = 0
}

/// Per-layer render memory. Never touched by the main thread while the engine runs.
struct NTLayerState {
    var phase: Double = 0
    var lfoPhase: Double = 0
    var currentGain: Double = 0
    var rng = NTRandom()
    var pink = NTPinkState()
    var brown = NTBrownState()
    var diffA = NTDiffState()
    var diffB = NTDiffState()
    var z0 = NTZ(), z1 = NTZ(), z2 = NTZ(), z3 = NTZ()
    var zg0 = NTZ(), zg1 = NTZ(), zg2 = NTZ()
    var envValue: Double = 0.5
    var envTarget: Double = 0.5
    var combIndex: Int32 = 0
}

struct NTMasterParams {
    var gain: Double = 0
    var running: Int32 = 0
    var smoothing: Double = 0.0004   // one-pole coefficient for gain ramps
    /// Per-channel trims, used by the measurement screens to present to one ear.
    var panL: Double = 1
    var panR: Double = 1
}

/// Soft cubic limiter. Slope is exactly 1 at zero, so the limiter can only ever reduce
/// a sample, never add gain: the output ceiling set in Settings stays a real ceiling.
/// f(x) = x - x^3/3, clamped to its own saturation value of ±2/3 outside ±1.
@inline(__always)
func ntSoftLimit(_ x: Double) -> Double {
    if x >= 1.0 { return 2.0 / 3.0 }
    if x <= -1.0 { return -2.0 / 3.0 }
    return x - (x * x * x) / 3.0
}

/// Maximum comb delay in samples (about 25 ms at 48 kHz), allocated once at engine setup.
let NTMaxCombDelay: Int = 1200

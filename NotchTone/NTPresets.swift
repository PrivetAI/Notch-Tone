import Foundation

/// The eight authored starting points that ship with Notch Tone. Presets marked
/// `followsProfile` re-centre themselves on whatever frequency the user has matched,
/// so the library grows more personal as the profile fills in.
enum NTPresetLibrary {

    static let defaultFrequency: Double = 4000

    static func builtIn(profileFrequency: Double?) -> [NTPreset] {
        let f = NTNum.clamp(profileFrequency ?? defaultFrequency, 250, 12000)

        var list: [NTPreset] = []

        list.append(NTPreset(
            id: "nt-notch-wide",
            name: "Notch, Wide",
            detail: "Pink noise with a one-and-a-half octave gap around your matched frequency. The gentlest starting point: plenty of sound, a broad quiet band where your tinnitus sits.",
            layers: [
                NTLayerConfig(kind: .notchedNoise, colour: .pink, frequency: f, notchOctaves: 1.5, level: 0.62)
            ],
            isBuiltIn: true, followsProfile: true))

        list.append(NTPreset(
            id: "nt-notch-standard",
            name: "Notch, Standard",
            detail: "The one-octave notch. This is the configuration most descriptions of notched sound have in mind, and the one to come back to.",
            layers: [
                NTLayerConfig(kind: .notchedNoise, colour: .pink, frequency: f, notchOctaves: 1.0, level: 0.62)
            ],
            isBuiltIn: true, followsProfile: true))

        list.append(NTPreset(
            id: "nt-notch-narrow",
            name: "Notch, Narrow",
            detail: "A half-octave notch over white noise. Brighter and more precise; some people prefer the tighter gap once they are used to the wider one.",
            layers: [
                NTLayerConfig(kind: .notchedNoise, colour: .white, frequency: f, notchOctaves: 0.5, level: 0.55)
            ],
            isBuiltIn: true, followsProfile: true))

        list.append(NTPreset(
            id: "nt-notch-surf",
            name: "Notch Over Surf",
            detail: "A standard notch layered over slowly modulated brown noise. The moving bed gives the ear something to follow so the sound does not become a flat wall.",
            layers: [
                NTLayerConfig(kind: .notchedNoise, colour: .pink, frequency: f, notchOctaves: 1.0, level: 0.48),
                NTLayerConfig(kind: .modulatedBrown, colour: .brown, modRate: 0.09, modDepth: 0.62, cutoff: 1400, level: 0.55)
            ],
            isBuiltIn: true, followsProfile: true))

        list.append(NTPreset(
            id: "nt-night-bed",
            name: "Night Bed",
            detail: "Deep brown noise with a very slow breath and a soft fan bed underneath. Built for a bedside table, with almost no energy above two kilohertz.",
            layers: [
                NTLayerConfig(kind: .modulatedBrown, colour: .brown, modRate: 0.06, modDepth: 0.45, cutoff: 900, level: 0.62),
                NTLayerConfig(kind: .fanBed, colour: .brown, modRate: 0.25, modDepth: 0.12, cutoff: 700, level: 0.40)
            ],
            isBuiltIn: true))

        list.append(NTPreset(
            id: "nt-rain-glass",
            name: "Rain On Glass",
            detail: "Band-passed noise driven by a fast random envelope. No recordings involved: the pattering is generated one sample at a time.",
            layers: [
                NTLayerConfig(kind: .rainBed, colour: .white, frequency: 2600, modRate: 0.2, modDepth: 0.2, level: 0.55),
                NTLayerConfig(kind: .fanBed, colour: .brown, modRate: 0.1, modDepth: 0.1, cutoff: 600, level: 0.34)
            ],
            isBuiltIn: true))

        list.append(NTPreset(
            id: "nt-partial-cover",
            name: "Partial Cover",
            detail: "A quiet notched bed plus a narrow band of noise just below your matched frequency. Aimed at partial masking, where your tinnitus is still faintly audible rather than buried.",
            layers: [
                NTLayerConfig(kind: .notchedNoise, colour: .pink, frequency: f, notchOctaves: 1.0, level: 0.40),
                NTLayerConfig(kind: .bandNoise, colour: .white, frequency: max(300, f * 0.62), bandOctaves: 1.0, level: 0.34)
            ],
            isBuiltIn: true, followsProfile: true))

        list.append(NTPreset(
            id: "nt-leaves-air",
            name: "Leaves And Air",
            detail: "Comb-filtered low noise over a soft grey bed. Dry, airy and unusually easy to leave running while reading or working.",
            layers: [
                NTLayerConfig(kind: .leavesBed, colour: .pink, modRate: 0.14, modDepth: 0.5, cutoff: 3200, level: 0.50),
                NTLayerConfig(kind: .colourNoise, colour: .grey, level: 0.28)
            ],
            isBuiltIn: true))

        return list
    }

    /// Rebuild a preset's layers so that a profile-following preset always uses the
    /// current matched frequency, even if the profile changed after the preset was listed.
    static func resolved(_ preset: NTPreset, profileFrequency: Double?) -> [NTPreset.LayerResolution] {
        var out: [NTPreset.LayerResolution] = []
        let f = profileFrequency
        for layer in preset.layers {
            var l = layer
            l.id = UUID()
            if preset.followsProfile, let freq = f {
                switch l.kind {
                case .notchedNoise, .pureTone:
                    l.frequency = NTNum.clamp(freq, 120, 12000)
                case .bandNoise:
                    l.frequency = NTNum.clamp(freq * 0.62, 120, 12000)
                default:
                    break
                }
            }
            out.append(NTPreset.LayerResolution(config: l))
        }
        return out
    }
}

extension NTPreset {
    struct LayerResolution {
        var config: NTLayerConfig
    }

    /// Layers ready to hand to the synthesiser.
    func resolvedLayers(profileFrequency: Double?) -> [NTLayerConfig] {
        NTPresetLibrary.resolved(self, profileFrequency: profileFrequency).map { $0.config }
    }
}

/// The catalogue of generators offered on the Sound tab, with the copy that explains each.
struct NTGeneratorSpec: Identifiable {
    let id: String
    let kind: NTGenKind
    let title: String
    let group: String
    let blurb: String
    let makeDefault: (Double?) -> NTLayerConfig
}

enum NTGeneratorCatalogue {

    static let groups: [String] = ["Tailored", "Noise colours", "Shaped noise", "Textured beds"]

    static let all: [NTGeneratorSpec] = [
        NTGeneratorSpec(
            id: "notched",
            kind: .notchedNoise,
            title: "Notched noise",
            group: "Tailored",
            blurb: "Broadband noise with a band removed around your matched frequency, built from four cascaded band-reject sections. This is the sound the app is named after.",
            makeDefault: { f in
                NTLayerConfig(kind: .notchedNoise, colour: .pink,
                              frequency: NTNum.clamp(f ?? 4000, 250, 12000),
                              notchOctaves: 1.0, level: 0.6)
            }),
        NTGeneratorSpec(
            id: "band",
            kind: .bandNoise,
            title: "Band-limited noise",
            group: "Tailored",
            blurb: "A band-pass filter around a centre you choose, so the energy sits in one region instead of across the whole spectrum.",
            makeDefault: { f in
                NTLayerConfig(kind: .bandNoise, colour: .white,
                              frequency: NTNum.clamp((f ?? 4000) * 0.7, 250, 12000),
                              bandOctaves: 1.0, level: 0.5)
            }),
        NTGeneratorSpec(
            id: "tone",
            kind: .pureTone,
            title: "Pure tone",
            group: "Tailored",
            blurb: "A single sine wave at an exact frequency. Mostly used by the matching procedures, but available here for reference listening. Keep it very quiet.",
            makeDefault: { f in
                NTLayerConfig(kind: .pureTone, colour: .white,
                              frequency: NTNum.clamp(f ?? 4000, 100, 12000),
                              level: 0.18)
            }),
        NTGeneratorSpec(
            id: "colour",
            kind: .colourNoise,
            title: "Noise colour",
            group: "Noise colours",
            blurb: "Six spectral slopes, each generated by a real filter chain rather than by scaling white noise. Pick the one that sits most comfortably.",
            makeDefault: { _ in
                NTLayerConfig(kind: .colourNoise, colour: .pink, level: 0.55)
            }),
        NTGeneratorSpec(
            id: "ambrown",
            kind: .modulatedBrown,
            title: "Modulated brown",
            group: "Shaped noise",
            blurb: "Brown noise under a slow amplitude sweep. The rise and fall reads as surf or as slow breathing, with no recorded material involved.",
            makeDefault: { _ in
                NTLayerConfig(kind: .modulatedBrown, colour: .brown, modRate: 0.09,
                              modDepth: 0.6, cutoff: 1200, level: 0.55)
            }),
        NTGeneratorSpec(
            id: "fan",
            kind: .fanBed,
            title: "Fan bed",
            group: "Textured beds",
            blurb: "Twice-low-passed noise with the deep rumble trimmed away. The steady hum of a fan in the next room.",
            makeDefault: { _ in
                NTLayerConfig(kind: .fanBed, colour: .brown, modRate: 0.2, modDepth: 0.1,
                              cutoff: 900, level: 0.5)
            }),
        NTGeneratorSpec(
            id: "rain",
            kind: .rainBed,
            title: "Rain bed",
            group: "Textured beds",
            blurb: "A band-pass around your chosen centre, driven by a fast random envelope so the level flickers the way rain does.",
            makeDefault: { _ in
                NTLayerConfig(kind: .rainBed, colour: .white, frequency: 2600, level: 0.5)
            }),
        NTGeneratorSpec(
            id: "leaves",
            kind: .leavesBed,
            title: "Leaves bed",
            group: "Textured beds",
            blurb: "Low-passed noise through a short comb delay. The comb adds a faint resonant colour that reads as dry leaves rather than as hiss.",
            makeDefault: { _ in
                NTLayerConfig(kind: .leavesBed, colour: .pink, modRate: 0.14, modDepth: 0.5,
                              cutoff: 3000, level: 0.5)
            })
    ]

    static func spec(for kind: NTGenKind) -> NTGeneratorSpec? {
        all.first(where: { $0.kind == kind })
    }
}

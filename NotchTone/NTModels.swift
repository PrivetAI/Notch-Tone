import Foundation

// Every Codable below implements a defensive `init(from:)` built on decodeIfPresent, so
// adding a field in a later version can never wipe a user's saved data.

// MARK: - Generator layer configuration

struct NTLayerConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var enabled: Bool = true
    var kindRaw: Int32 = NTGenKind.notchedNoise.rawValue
    var colourRaw: Int32 = NTNoiseColour.pink.rawValue
    /// Tone frequency, notch centre or band centre, in hertz.
    var frequency: Double = 4000
    /// Notch width in octaves: 0.5, 1.0 or 1.5.
    var notchOctaves: Double = 1.0
    /// Band-pass width in octaves.
    var bandOctaves: Double = 1.0
    /// Modulation rate in hertz.
    var modRate: Double = 0.12
    /// Modulation depth 0 - 1.
    var modDepth: Double = 0.55
    /// Low-pass corner for the fan and leaves beds.
    var cutoff: Double = 2200
    /// Layer level 0 - 1.
    var level: Double = 0.7

    var kind: NTGenKind {
        get { NTGenKind(rawValue: kindRaw) ?? .colourNoise }
        set { kindRaw = newValue.rawValue }
    }

    var colour: NTNoiseColour {
        get { NTNoiseColour(rawValue: colourRaw) ?? .pink }
        set { colourRaw = newValue.rawValue }
    }

    init() {}

    init(kind: NTGenKind,
         colour: NTNoiseColour = .pink,
         frequency: Double = 4000,
         notchOctaves: Double = 1.0,
         bandOctaves: Double = 1.0,
         modRate: Double = 0.12,
         modDepth: Double = 0.55,
         cutoff: Double = 2200,
         level: Double = 0.7,
         enabled: Bool = true) {
        self.kindRaw = kind.rawValue
        self.colourRaw = colour.rawValue
        self.frequency = frequency
        self.notchOctaves = notchOctaves
        self.bandOctaves = bandOctaves
        self.modRate = modRate
        self.modDepth = modDepth
        self.cutoff = cutoff
        self.level = level
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true
        kindRaw = (try? c.decodeIfPresent(Int32.self, forKey: .kindRaw)) ?? NTGenKind.colourNoise.rawValue
        colourRaw = (try? c.decodeIfPresent(Int32.self, forKey: .colourRaw)) ?? NTNoiseColour.pink.rawValue
        frequency = (try? c.decodeIfPresent(Double.self, forKey: .frequency)) ?? 4000
        notchOctaves = (try? c.decodeIfPresent(Double.self, forKey: .notchOctaves)) ?? 1.0
        bandOctaves = (try? c.decodeIfPresent(Double.self, forKey: .bandOctaves)) ?? 1.0
        modRate = (try? c.decodeIfPresent(Double.self, forKey: .modRate)) ?? 0.12
        modDepth = (try? c.decodeIfPresent(Double.self, forKey: .modDepth)) ?? 0.55
        cutoff = (try? c.decodeIfPresent(Double.self, forKey: .cutoff)) ?? 2200
        level = (try? c.decodeIfPresent(Double.self, forKey: .level)) ?? 0.7
    }

    var displayName: String {
        switch kind {
        case .pureTone: return "Pure tone"
        case .colourNoise: return "\(colour.title) noise"
        case .notchedNoise: return "Notched \(colour.title.lowercased()) noise"
        case .bandNoise: return "Band-limited noise"
        case .modulatedBrown: return "Modulated brown"
        case .fanBed: return "Fan bed"
        case .rainBed: return "Rain bed"
        case .leavesBed: return "Leaves bed"
        }
    }

    /// A one-line readout of the parameters that matter for this kind.
    var readout: String {
        switch kind {
        case .pureTone: return NTNum.hz(frequency)
        case .colourNoise: return colour.slopeLabel
        case .notchedNoise: return NTNum.hz(frequency) + " · " + NTOctave.label(notchOctaves) + " notch"
        case .bandNoise: return NTNum.hz(frequency) + " · " + NTOctave.label(bandOctaves) + " band"
        case .modulatedBrown: return String(format: "%.2f Hz sweep · %.0f%% depth", modRate, modDepth * 100)
        case .fanBed: return NTNum.hz(cutoff) + " low-pass"
        case .rainBed: return NTNum.hz(frequency) + " centre"
        case .leavesBed: return NTNum.hz(cutoff) + " low-pass · comb"
        }
    }
}

enum NTOctave {
    static let choices: [Double] = [0.5, 1.0, 1.5]

    static func label(_ v: Double) -> String {
        if abs(v - 0.5) < 0.01 { return "1/2 oct" }
        if abs(v - 1.5) < 0.01 { return "1 1/2 oct" }
        if abs(v - 1.0) < 0.01 { return "1 oct" }
        return String(format: "%.1f oct", v)
    }

    static func index(_ v: Double) -> Int {
        var best = 1
        var bestD = Double.greatestFiniteMagnitude
        for (i, c) in choices.enumerated() {
            let d = abs(c - v)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }
}

// MARK: - Presets

struct NTPreset: Codable, Identifiable, Equatable {
    /// A stable key. Built-ins use a fixed string so SwiftUI identity does not churn
    /// every time the library is rebuilt; saved presets use a fresh UUID string.
    var id: String = UUID().uuidString
    var name: String = "Preset"
    var detail: String = ""
    var layers: [NTLayerConfig] = []
    var isBuiltIn: Bool = false
    /// Built-in presets that re-centre themselves on the user's matched frequency.
    var followsProfile: Bool = false
    var createdAt: Date = Date()

    init(id: String = UUID().uuidString, name: String, detail: String, layers: [NTLayerConfig],
         isBuiltIn: Bool = false, followsProfile: Bool = false) {
        self.id = id
        self.name = name
        self.detail = detail
        self.layers = layers
        self.isBuiltIn = isBuiltIn
        self.followsProfile = followsProfile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Preset"
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? ""
        layers = (try? c.decodeIfPresent([NTLayerConfig].self, forKey: .layers)) ?? []
        isBuiltIn = (try? c.decodeIfPresent(Bool.self, forKey: .isBuiltIn)) ?? false
        followsProfile = (try? c.decodeIfPresent(Bool.self, forKey: .followsProfile)) ?? false
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }
}

// MARK: - Measurement records

enum NTEar: Int, Codable, CaseIterable {
    case both = 0
    case left = 1
    case right = 2

    var title: String {
        switch self {
        case .both: return "Both"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

struct NTPitchRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var frequency: Double = 0
    var method: String = "bracket"
    var octaveChecked: Bool = false
    var earRaw: Int = 0
    var rounds: Int = 0

    var ear: NTEar { NTEar(rawValue: earRaw) ?? .both }

    init(frequency: Double, method: String, octaveChecked: Bool, ear: NTEar, rounds: Int) {
        self.frequency = frequency
        self.method = method
        self.octaveChecked = octaveChecked
        self.earRaw = ear.rawValue
        self.rounds = rounds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        frequency = (try? c.decodeIfPresent(Double.self, forKey: .frequency)) ?? 0
        method = (try? c.decodeIfPresent(String.self, forKey: .method)) ?? "bracket"
        octaveChecked = (try? c.decodeIfPresent(Bool.self, forKey: .octaveChecked)) ?? false
        earRaw = (try? c.decodeIfPresent(Int.self, forKey: .earRaw)) ?? 0
        rounds = (try? c.decodeIfPresent(Int.self, forKey: .rounds)) ?? 0
    }
}

struct NTLoudnessRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var frequency: Double = 0
    /// Relative in-app decibels. Zero is the app's own reference level; values are negative.
    var relativeDb: Double = 0
    var earRaw: Int = 0

    var ear: NTEar { NTEar(rawValue: earRaw) ?? .both }

    init(frequency: Double, relativeDb: Double, ear: NTEar) {
        self.frequency = frequency
        self.relativeDb = relativeDb
        self.earRaw = ear.rawValue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        frequency = (try? c.decodeIfPresent(Double.self, forKey: .frequency)) ?? 0
        relativeDb = (try? c.decodeIfPresent(Double.self, forKey: .relativeDb)) ?? 0
        earRaw = (try? c.decodeIfPresent(Int.self, forKey: .earRaw)) ?? 0
    }
}

struct NTMaskingRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var relativeDb: Double = 0
    var colourRaw: Int32 = NTNoiseColour.white.rawValue
    var notCovered: Bool = false

    var colour: NTNoiseColour { NTNoiseColour(rawValue: colourRaw) ?? .white }

    init(relativeDb: Double, colour: NTNoiseColour, notCovered: Bool) {
        self.relativeDb = relativeDb
        self.colourRaw = colour.rawValue
        self.notCovered = notCovered
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        relativeDb = (try? c.decodeIfPresent(Double.self, forKey: .relativeDb)) ?? 0
        colourRaw = (try? c.decodeIfPresent(Int32.self, forKey: .colourRaw)) ?? NTNoiseColour.white.rawValue
        notCovered = (try? c.decodeIfPresent(Bool.self, forKey: .notCovered)) ?? false
    }
}

struct NTSelfCheckRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var answers: [Int] = []
    var total: Int = 0

    init(answers: [Int]) {
        self.answers = answers
        self.total = answers.reduce(0, +)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        answers = (try? c.decodeIfPresent([Int].self, forKey: .answers)) ?? []
        total = (try? c.decodeIfPresent(Int.self, forKey: .total)) ?? 0
    }
}

// MARK: - Profile

struct NTProfile: Codable, Equatable {
    var matchedFrequency: Double? = nil
    var matchedAt: Date? = nil
    var loudnessDb: Double? = nil
    var loudnessAt: Date? = nil
    var maskingDb: Double? = nil
    var maskingAt: Date? = nil
    var maskingColourRaw: Int32? = nil
    var preferredEarRaw: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchedFrequency = (try? c.decodeIfPresent(Double.self, forKey: .matchedFrequency)) ?? nil
        matchedAt = (try? c.decodeIfPresent(Date.self, forKey: .matchedAt)) ?? nil
        loudnessDb = (try? c.decodeIfPresent(Double.self, forKey: .loudnessDb)) ?? nil
        loudnessAt = (try? c.decodeIfPresent(Date.self, forKey: .loudnessAt)) ?? nil
        maskingDb = (try? c.decodeIfPresent(Double.self, forKey: .maskingDb)) ?? nil
        maskingAt = (try? c.decodeIfPresent(Date.self, forKey: .maskingAt)) ?? nil
        maskingColourRaw = (try? c.decodeIfPresent(Int32.self, forKey: .maskingColourRaw)) ?? nil
        preferredEarRaw = (try? c.decodeIfPresent(Int.self, forKey: .preferredEarRaw)) ?? 0
    }

    var hasPitch: Bool { (matchedFrequency ?? 0) > 100 }

    var ear: NTEar { NTEar(rawValue: preferredEarRaw) ?? .both }

    var maskingColour: NTNoiseColour {
        NTNoiseColour(rawValue: maskingColourRaw ?? NTNoiseColour.white.rawValue) ?? .white
    }
}

// MARK: - Diary

struct NTFactor: Identifiable, Equatable {
    let id: String
    let title: String
    let hint: String
}

enum NTFactors {
    /// The authored factor set offered on every diary entry.
    static let all: [NTFactor] = [
        NTFactor(id: "noise", title: "Loud noise", hint: "A concert, power tools, loud transport, or headphones turned up."),
        NTFactor(id: "sleep", title: "Poor sleep", hint: "A short night, broken sleep, or waking unrested."),
        NTFactor(id: "stress", title: "Stress", hint: "A demanding, tense or anxious day."),
        NTFactor(id: "caffeine", title: "Caffeine", hint: "Coffee, strong tea or energy drinks, especially late in the day."),
        NTFactor(id: "alcohol", title: "Alcohol", hint: "Any alcohol during the day or the evening before."),
        NTFactor(id: "salt", title: "Salty food", hint: "A noticeably salty meal or snack."),
        NTFactor(id: "hydration", title: "Dehydration", hint: "Drank noticeably less water than usual."),
        NTFactor(id: "illness", title: "Illness or congestion", hint: "A cold, blocked nose, sinus pressure or a feeling of fullness."),
        NTFactor(id: "jaw", title: "Jaw or neck tension", hint: "Clenching, grinding, or a stiff neck and shoulders."),
        NTFactor(id: "meds", title: "Medication change", hint: "Started, stopped, or changed the dose of something."),
        NTFactor(id: "exercise", title: "Exercise", hint: "A deliberate workout, run, swim or long walk."),
        NTFactor(id: "quiet", title: "Quiet day", hint: "Spent much of the day in a very quiet environment.")
    ]

    static func title(for id: String) -> String {
        all.first(where: { $0.id == id })?.title ?? id
    }
}

struct NTDiaryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// yyyymmdd, so day comparisons are integer comparisons.
    var dayKey: Int = 0
    var loudness: Int = 5
    var annoyance: Int = 5
    var sleepQuality: Int = 5
    var factors: [String] = []
    var note: String = ""
    var savedAt: Date = Date()

    init(dayKey: Int) {
        self.dayKey = dayKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        dayKey = (try? c.decodeIfPresent(Int.self, forKey: .dayKey)) ?? 0
        loudness = (try? c.decodeIfPresent(Int.self, forKey: .loudness)) ?? 5
        annoyance = (try? c.decodeIfPresent(Int.self, forKey: .annoyance)) ?? 5
        sleepQuality = (try? c.decodeIfPresent(Int.self, forKey: .sleepQuality)) ?? 5
        factors = (try? c.decodeIfPresent([String].self, forKey: .factors)) ?? []
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        savedAt = (try? c.decodeIfPresent(Date.self, forKey: .savedAt)) ?? Date()
    }

    var date: Date { NTFormat.date(fromDayKey: dayKey) }
}

// MARK: - Session log

struct NTSessionLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var seconds: Int = 0
    var summary: String = ""
    var dayKey: Int = 0

    init(startedAt: Date, seconds: Int, summary: String) {
        self.startedAt = startedAt
        self.seconds = seconds
        self.summary = summary
        self.dayKey = NTFormat.dayKey(startedAt)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        startedAt = (try? c.decodeIfPresent(Date.self, forKey: .startedAt)) ?? Date()
        seconds = (try? c.decodeIfPresent(Int.self, forKey: .seconds)) ?? 0
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        dayKey = (try? c.decodeIfPresent(Int.self, forKey: .dayKey)) ?? 0
    }
}

// MARK: - Persisted settings

struct NTSettings: Codable, Equatable {
    /// Hard ceiling applied to the synthesiser's output amplitude.
    var outputCap: Double = 0.32
    /// Default sleep timer, an index into NTSleepTimer.options.
    var defaultTimerIndex: Int = 2
    /// Ramp-in time constant in seconds. Never zero, so nothing ever starts with a click.
    var fadeSeconds: Double = 0.3
    /// Length of the slow fade at the end of a timed session, in seconds.
    var endFadeSeconds: Double = 60
    var keepPlayingInBackground: Bool = true
    var showLevelReadout: Bool = true
    var hasSeenOnboarding: Bool = false
    var hasAcceptedVolumeWarning: Bool = false
    var lastMasterLevel: Double = 0.45
    /// The generator stack as the user left it, so a sleep session survives a relaunch.
    var lastLayers: [NTLayerConfig] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        outputCap = (try? c.decodeIfPresent(Double.self, forKey: .outputCap)) ?? 0.32
        defaultTimerIndex = (try? c.decodeIfPresent(Int.self, forKey: .defaultTimerIndex)) ?? 2
        fadeSeconds = (try? c.decodeIfPresent(Double.self, forKey: .fadeSeconds)) ?? 0.3
        endFadeSeconds = (try? c.decodeIfPresent(Double.self, forKey: .endFadeSeconds)) ?? 60
        keepPlayingInBackground = (try? c.decodeIfPresent(Bool.self, forKey: .keepPlayingInBackground)) ?? true
        showLevelReadout = (try? c.decodeIfPresent(Bool.self, forKey: .showLevelReadout)) ?? true
        hasSeenOnboarding = (try? c.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding)) ?? false
        hasAcceptedVolumeWarning = (try? c.decodeIfPresent(Bool.self, forKey: .hasAcceptedVolumeWarning)) ?? false
        lastMasterLevel = (try? c.decodeIfPresent(Double.self, forKey: .lastMasterLevel)) ?? 0.45
        lastLayers = (try? c.decodeIfPresent([NTLayerConfig].self, forKey: .lastLayers)) ?? []
    }
}

enum NTSleepTimer {
    /// Minutes; zero means "until I stop".
    static let options: [Int] = [15, 30, 45, 60, 90, 0]

    static func label(_ minutes: Int) -> String {
        minutes == 0 ? "Open" : "\(minutes)m"
    }

    static func longLabel(_ minutes: Int) -> String {
        minutes == 0 ? "Until I stop" : "\(minutes) minutes"
    }
}

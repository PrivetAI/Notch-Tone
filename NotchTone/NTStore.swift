import Foundation
import SwiftUI

/// Everything Notch Tone remembers. Local only — JSON files in Application Support,
/// plus a single UserDefaults key for the small settings block. Nothing leaves the phone.
final class NTStore: ObservableObject {

    @Published var settings: NTSettings = NTSettings() { didSet { scheduleSave(.settings) } }
    @Published var profile: NTProfile = NTProfile() { didSet { scheduleSave(.profile) } }
    @Published var pitchRecords: [NTPitchRecord] = [] { didSet { scheduleSave(.measurements) } }
    @Published var loudnessRecords: [NTLoudnessRecord] = [] { didSet { scheduleSave(.measurements) } }
    @Published var maskingRecords: [NTMaskingRecord] = [] { didSet { scheduleSave(.measurements) } }
    @Published var selfChecks: [NTSelfCheckRecord] = [] { didSet { scheduleSave(.measurements) } }
    @Published var diary: [NTDiaryEntry] = [] { didSet { scheduleSave(.diary) } }
    @Published var sessions: [NTSessionLog] = [] { didSet { scheduleSave(.diary) } }
    @Published var userPresets: [NTPreset] = [] { didSet { scheduleSave(.presets) } }
    @Published var readCardIDs: Set<String> = [] { didSet { scheduleSave(.reading) } }
    @Published var bookmarkedCardIDs: Set<String> = [] { didSet { scheduleSave(.reading) } }

    private enum Bucket { case settings, profile, measurements, diary, presets, reading }

    private var loading = true
    private let fm = FileManager.default
    /// Writes are coalesced: a slider drag would otherwise rewrite a JSON file per frame.
    private var pendingBuckets: Set<String> = []
    private var flushWork: DispatchWorkItem? = nil
    private var observerTokens: [NSObjectProtocol] = []

    init() {
        load()
        loading = false
        let nc = NotificationCenter.default
        for name in [UIApplication.didEnterBackgroundNotification,
                     UIApplication.willTerminateNotification,
                     UIApplication.willResignActiveNotification] {
            observerTokens.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.flushNow()
            })
        }
    }

    deinit {
        for t in observerTokens { NotificationCenter.default.removeObserver(t) }
        flushWork?.cancel()
        writePending()
    }

    /// Write anything still queued immediately. Called when the app leaves the foreground.
    func flushNow() {
        flushWork?.cancel()
        flushWork = nil
        writePending()
    }

    // MARK: - Paths

    private var folder: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("NotchTone", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    // MARK: - Load

    private struct MeasurementsFile: Codable {
        var pitch: [NTPitchRecord] = []
        var loudness: [NTLoudnessRecord] = []
        var masking: [NTMaskingRecord] = []
        var checks: [NTSelfCheckRecord] = []

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            pitch = (try? c.decodeIfPresent([NTPitchRecord].self, forKey: .pitch)) ?? []
            loudness = (try? c.decodeIfPresent([NTLoudnessRecord].self, forKey: .loudness)) ?? []
            masking = (try? c.decodeIfPresent([NTMaskingRecord].self, forKey: .masking)) ?? []
            checks = (try? c.decodeIfPresent([NTSelfCheckRecord].self, forKey: .checks)) ?? []
        }
    }

    private struct DiaryFile: Codable {
        var entries: [NTDiaryEntry] = []
        var sessions: [NTSessionLog] = []

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entries = (try? c.decodeIfPresent([NTDiaryEntry].self, forKey: .entries)) ?? []
            sessions = (try? c.decodeIfPresent([NTSessionLog].self, forKey: .sessions)) ?? []
        }
    }

    private struct ReadingFile: Codable {
        var read: [String] = []
        var bookmarks: [String] = []

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            read = (try? c.decodeIfPresent([String].self, forKey: .read)) ?? []
            bookmarks = (try? c.decodeIfPresent([String].self, forKey: .bookmarks)) ?? []
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to name: String) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }

    private func load() {
        if let s = decode(NTSettings.self, from: "settings.json") { settings = s }
        if let p = decode(NTProfile.self, from: "profile.json") { profile = p }
        if let m = decode(MeasurementsFile.self, from: "measurements.json") {
            pitchRecords = m.pitch
            loudnessRecords = m.loudness
            maskingRecords = m.masking
            selfChecks = m.checks
        }
        if let d = decode(DiaryFile.self, from: "diary.json") {
            diary = d.entries
            sessions = d.sessions
        }
        if let pr = decode([NTPreset].self, from: "presets.json") { userPresets = pr }
        if let r = decode(ReadingFile.self, from: "reading.json") {
            readCardIDs = Set(r.read)
            bookmarkedCardIDs = Set(r.bookmarks)
        }
    }

    // MARK: - Save

    private func key(_ bucket: Bucket) -> String {
        switch bucket {
        case .settings: return "settings"
        case .profile: return "profile"
        case .measurements: return "measurements"
        case .diary: return "diary"
        case .presets: return "presets"
        case .reading: return "reading"
        }
    }

    private func bucket(_ key: String) -> Bucket {
        switch key {
        case "profile": return .profile
        case "measurements": return .measurements
        case "diary": return .diary
        case "presets": return .presets
        case "reading": return .reading
        default: return .settings
        }
    }

    private func scheduleSave(_ b: Bucket) {
        guard !loading else { return }
        pendingBuckets.insert(key(b))
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writePending() }
        flushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func writePending() {
        let buckets = pendingBuckets
        pendingBuckets.removeAll()
        for k in buckets { write(bucket(k)) }
    }

    private func write(_ bucket: Bucket) {
        switch bucket {
        case .settings:
            encode(settings, to: "settings.json")
        case .profile:
            encode(profile, to: "profile.json")
        case .measurements:
            var m = MeasurementsFile()
            m.pitch = pitchRecords
            m.loudness = loudnessRecords
            m.masking = maskingRecords
            m.checks = selfChecks
            encode(m, to: "measurements.json")
        case .diary:
            var d = DiaryFile()
            d.entries = diary
            d.sessions = sessions
            encode(d, to: "diary.json")
        case .presets:
            encode(userPresets, to: "presets.json")
        case .reading:
            var r = ReadingFile()
            r.read = Array(readCardIDs)
            r.bookmarks = Array(bookmarkedCardIDs)
            encode(r, to: "reading.json")
        }
    }

    func saveAll() {
        flushWork?.cancel()
        flushWork = nil
        pendingBuckets.removeAll()
        write(.settings)
        write(.profile)
        write(.measurements)
        write(.diary)
        write(.presets)
        write(.reading)
    }

    // MARK: - Measurement recording

    func recordPitch(_ rec: NTPitchRecord) {
        pitchRecords.insert(rec, at: 0)
        if pitchRecords.count > 200 { pitchRecords.removeLast(pitchRecords.count - 200) }
        profile.matchedFrequency = rec.frequency
        profile.matchedAt = rec.date
        profile.preferredEarRaw = rec.earRaw
    }

    func recordLoudness(_ rec: NTLoudnessRecord) {
        loudnessRecords.insert(rec, at: 0)
        if loudnessRecords.count > 200 { loudnessRecords.removeLast(loudnessRecords.count - 200) }
        profile.loudnessDb = rec.relativeDb
        profile.loudnessAt = rec.date
    }

    func recordMasking(_ rec: NTMaskingRecord) {
        maskingRecords.insert(rec, at: 0)
        if maskingRecords.count > 200 { maskingRecords.removeLast(maskingRecords.count - 200) }
        if !rec.notCovered {
            profile.maskingDb = rec.relativeDb
            profile.maskingAt = rec.date
            profile.maskingColourRaw = rec.colourRaw
        }
    }

    func recordSelfCheck(_ rec: NTSelfCheckRecord) {
        selfChecks.insert(rec, at: 0)
        if selfChecks.count > 200 { selfChecks.removeLast(selfChecks.count - 200) }
    }

    // MARK: - Diary

    func entry(for dayKey: Int) -> NTDiaryEntry? {
        diary.first(where: { $0.dayKey == dayKey })
    }

    func upsert(_ entry: NTDiaryEntry) {
        if let idx = diary.firstIndex(where: { $0.dayKey == entry.dayKey }) {
            var e = entry
            e.id = diary[idx].id
            e.savedAt = Date()
            diary[idx] = e
        } else {
            var e = entry
            e.savedAt = Date()
            diary.append(e)
        }
        diary.sort { $0.dayKey > $1.dayKey }
    }

    func deleteEntry(dayKey: Int) {
        diary.removeAll { $0.dayKey == dayKey }
    }

    func addSession(_ log: NTSessionLog) {
        sessions.insert(log, at: 0)
        if sessions.count > 400 { sessions.removeLast(sessions.count - 400) }
    }

    /// Total listening seconds recorded on a given day.
    func listeningSeconds(dayKey: Int) -> Int {
        sessions.filter { $0.dayKey == dayKey }.reduce(0) { $0 + $1.seconds }
    }

    var totalListeningSeconds: Int {
        sessions.reduce(0) { $0 + $1.seconds }
    }

    /// Consecutive days with a diary entry, counting back from today.
    var diaryStreak: Int {
        guard !diary.isEmpty else { return 0 }
        let keys = Set(diary.map { $0.dayKey })
        var streak = 0
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        var day = Date()
        for _ in 0..<400 {
            if keys.contains(NTFormat.dayKey(day)) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else if streak == 0 && NTFormat.dayKey(day) == NTFormat.dayKey(Date()) {
                // Today not filled in yet — look at yesterday before giving up.
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Correlation engine

    struct NTFactorStat: Identifiable {
        var id: String
        var title: String
        var withCount: Int
        var withoutCount: Int
        var meanWith: Double
        var meanWithout: Double
        var difference: Double
        var hasEnoughData: Bool
    }

    /// For every authored factor, the mean of the chosen metric on days the factor was
    /// logged versus days it was not. This is an association inside the user's own log,
    /// nothing more, and the UI says so.
    func factorStats(metric: NTDiaryMetric, minimumSamples: Int = 5) -> [NTFactorStat] {
        var result: [NTFactorStat] = []
        let entries = diary
        for factor in NTFactors.all {
            var withValues: [Double] = []
            var withoutValues: [Double] = []
            for e in entries {
                let v = Double(metric.value(from: e))
                if e.factors.contains(factor.id) { withValues.append(v) } else { withoutValues.append(v) }
            }
            let mw = withValues.isEmpty ? 0 : NTNum.safeDiv(withValues.reduce(0, +), Double(withValues.count))
            let mo = withoutValues.isEmpty ? 0 : NTNum.safeDiv(withoutValues.reduce(0, +), Double(withoutValues.count))
            let enough = withValues.count >= minimumSamples && withoutValues.count >= minimumSamples
            result.append(NTFactorStat(id: factor.id,
                                       title: factor.title,
                                       withCount: withValues.count,
                                       withoutCount: withoutValues.count,
                                       meanWith: mw,
                                       meanWithout: mo,
                                       difference: enough ? mw - mo : 0,
                                       hasEnoughData: enough))
        }
        return result.sorted { a, b in
            if a.hasEnoughData != b.hasEnoughData { return a.hasEnoughData }
            return abs(a.difference) > abs(b.difference)
        }
    }

    /// Mean of a metric over the entries that fall inside the last `days` calendar days.
    /// A real date window, not the last `days` entries: seven entries spread over three
    /// months are not a seven-day average, and the label says days.
    func recentMean(_ metric: NTDiaryMetric, days: Int) -> Double? {
        let cutoff = NTFormat.dayKey(daysAgo: max(1, days) - 1)
        let slice = diary.filter { $0.dayKey >= cutoff }
        guard !slice.isEmpty else { return nil }
        let sum = slice.reduce(0.0) { $0 + Double(metric.value(from: $1)) }
        return NTNum.safeDiv(sum, Double(slice.count))
    }

    /// Comparison of the last `window` days against the `window` days before them. Both
    /// windows are real date ranges, so "against the week before" means the week before.
    func trend(_ metric: NTDiaryMetric, window: Int) -> Double? {
        let w = max(1, window)
        let recentCutoff = NTFormat.dayKey(daysAgo: w - 1)
        let olderCutoff = NTFormat.dayKey(daysAgo: w * 2 - 1)
        let recent = diary.filter { $0.dayKey >= recentCutoff }
        let older = diary.filter { $0.dayKey >= olderCutoff && $0.dayKey < recentCutoff }
        guard !recent.isEmpty, !older.isEmpty else { return nil }
        let r = NTNum.safeDiv(recent.reduce(0.0) { $0 + Double(metric.value(from: $1)) }, Double(recent.count))
        let o = NTNum.safeDiv(older.reduce(0.0) { $0 + Double(metric.value(from: $1)) }, Double(older.count))
        return r - o
    }

    /// Days on which a listening session happened, compared with days without one.
    func listeningComparison(metric: NTDiaryMetric, minimumSamples: Int = 5) -> NTFactorStat {
        let sessionDays = Set(sessions.filter { $0.seconds >= 300 }.map { $0.dayKey })
        var withValues: [Double] = []
        var withoutValues: [Double] = []
        for e in diary {
            let v = Double(metric.value(from: e))
            if sessionDays.contains(e.dayKey) { withValues.append(v) } else { withoutValues.append(v) }
        }
        let mw = withValues.isEmpty ? 0 : NTNum.safeDiv(withValues.reduce(0, +), Double(withValues.count))
        let mo = withoutValues.isEmpty ? 0 : NTNum.safeDiv(withoutValues.reduce(0, +), Double(withoutValues.count))
        let enough = withValues.count >= minimumSamples && withoutValues.count >= minimumSamples
        return NTFactorStat(id: "listening",
                            title: "Days with a listening session",
                            withCount: withValues.count,
                            withoutCount: withoutValues.count,
                            meanWith: mw,
                            meanWithout: mo,
                            difference: enough ? mw - mo : 0,
                            hasEnoughData: enough)
    }

    // MARK: - Destructive actions

    func resetProfile() {
        profile = NTProfile()
        pitchRecords.removeAll()
        loudnessRecords.removeAll()
        maskingRecords.removeAll()
    }

    func resetDiary() {
        diary.removeAll()
        sessions.removeAll()
    }

    func resetSelfChecks() {
        selfChecks.removeAll()
    }

    func resetEverything() {
        profile = NTProfile()
        pitchRecords.removeAll()
        loudnessRecords.removeAll()
        maskingRecords.removeAll()
        selfChecks.removeAll()
        diary.removeAll()
        sessions.removeAll()
        userPresets.removeAll()
        readCardIDs.removeAll()
        bookmarkedCardIDs.removeAll()
        var fresh = NTSettings()
        fresh.hasSeenOnboarding = true
        fresh.hasAcceptedVolumeWarning = false
        settings = fresh
        saveAll()
    }
}

/// The three numbers a diary entry carries, plus how each is described.
enum NTDiaryMetric: Int, CaseIterable, Identifiable {
    case loudness = 0
    case annoyance = 1
    case sleep = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .loudness: return "Loudness"
        case .annoyance: return "Annoyance"
        case .sleep: return "Sleep"
        }
    }

    var longTitle: String {
        switch self {
        case .loudness: return "Perceived loudness"
        case .annoyance: return "How much it bothered you"
        case .sleep: return "Sleep quality"
        }
    }

    var lowLabel: String {
        switch self {
        case .loudness: return "Barely there"
        case .annoyance: return "Not at all"
        case .sleep: return "Very poor"
        }
    }

    var highLabel: String {
        switch self {
        case .loudness: return "Very loud"
        case .annoyance: return "Extremely"
        case .sleep: return "Excellent"
        }
    }

    /// True when a higher number is the better outcome.
    var higherIsBetter: Bool { self == .sleep }

    var tint: Color {
        switch self {
        case .loudness: return NTTheme.seriesPitch
        case .annoyance: return NTTheme.seriesLoud
        case .sleep: return NTTheme.seriesMask
        }
    }

    func value(from entry: NTDiaryEntry) -> Int {
        switch self {
        case .loudness: return entry.loudness
        case .annoyance: return entry.annoyance
        case .sleep: return entry.sleepQuality
        }
    }
}

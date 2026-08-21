import SwiftUI

// MARK: - Visual identity
// Notch Tone reads like a piece of audio measurement equipment: deep indigo panels,
// fine graticules, a cool cyan accent, warm amber reserved strictly for safety warnings.
// The app is forced to Light in Info.plist, so every colour below is an explicit constant
// and the device appearance setting can never alter the instrument.

enum NTTheme {

    // Backgrounds
    static let deep = Color(red: 0.043, green: 0.055, blue: 0.106)      // near-black indigo
    static let panel = Color(red: 0.078, green: 0.098, blue: 0.176)     // instrument panel
    static let panelHigh = Color(red: 0.110, green: 0.137, blue: 0.239) // raised card
    static let panelEdge = Color(red: 0.180, green: 0.216, blue: 0.345) // hairline border

    // Accents
    static let cyan = Color(red: 0.298, green: 0.855, blue: 0.898)
    static let cyanDim = Color(red: 0.180, green: 0.545, blue: 0.596)
    static let indigo = Color(red: 0.400, green: 0.435, blue: 0.898)
    static let amber = Color(red: 0.980, green: 0.702, blue: 0.290)
    static let amberDeep = Color(red: 0.612, green: 0.400, blue: 0.114)

    // Text
    static let ink = Color(red: 0.910, green: 0.937, blue: 0.980)
    static let inkDim = Color(red: 0.639, green: 0.686, blue: 0.796)
    static let inkFaint = Color(red: 0.435, green: 0.478, blue: 0.588)

    // Graticule
    static let grid = Color(red: 0.161, green: 0.196, blue: 0.310)
    static let gridFaint = Color(red: 0.118, green: 0.145, blue: 0.239)

    // Series colours for charts (no emoji, no system palette)
    static let seriesPitch = Color(red: 0.298, green: 0.855, blue: 0.898)
    static let seriesLoud = Color(red: 0.612, green: 0.549, blue: 0.965)
    static let seriesMask = Color(red: 0.427, green: 0.812, blue: 0.639)
    static let seriesScore = Color(red: 0.980, green: 0.702, blue: 0.290)

    // Numerals: a monospaced digit face so readings do not jitter.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    static let corner: CGFloat = 14
}

// MARK: - Reusable chrome

/// A bordered instrument panel used for every card in the app.
struct NTPanel<Content: View>: View {
    var padding: CGFloat = 16
    var tint: Color = NTTheme.panelEdge
    let content: () -> Content

    init(padding: CGFloat = 16, tint: Color = NTTheme.panelEdge, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: NTTheme.corner, style: .continuous)
                    .fill(NTTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NTTheme.corner, style: .continuous)
                    .stroke(tint, lineWidth: 1)
            )
    }
}

/// Section heading with a drawn rule, used to organise long scrolls.
struct NTSectionHeader: View {
    let title: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(NTTheme.mono(12, .semibold))
                    .foregroundColor(NTTheme.cyan)
                    .tracking(1.4)
                NTRule()
            }
            if let caption = caption {
                Text(caption)
                    .font(NTTheme.rounded(12))
                    .foregroundColor(NTTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct NTRule: View {
    var color: Color = NTTheme.grid
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// Primary action button — a drawn capsule, never a system button style.
struct NTButtonLabel: View {
    let title: String
    var filled: Bool = true
    var tint: Color = NTTheme.cyan
    var compact: Bool = false

    var body: some View {
        Text(title)
            .font(NTTheme.rounded(compact ? 13 : 15, .semibold))
            .foregroundColor(filled ? NTTheme.deep : tint)
            .padding(.vertical, compact ? 8 : 12)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(filled ? tint : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(tint.opacity(filled ? 0.0 : 0.7), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

/// Amber safety callout. Used anywhere the app shows a clinical-sounding number.
struct NTSafetyNote: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NTWarnGlyph(size: 15, color: NTTheme.amber)
                .padding(.top, 1)
            Text(text)
                .font(NTTheme.rounded(12))
                .foregroundColor(NTTheme.amber.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(NTTheme.amberDeep.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(NTTheme.amber.opacity(0.42), lineWidth: 1)
        )
    }
}

/// Small neutral caption used under numbers that could be mistaken for clinical values.
struct NTInlineDisclaimer: View {
    let text: String
    var body: some View {
        Text(text)
            .font(NTTheme.rounded(11))
            .foregroundColor(NTTheme.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A status-bar strip painted in the app background so scrolled content never
/// draws over the clock. Must be added as the LAST sibling of the root ZStack.
struct NTStatusStrip: View {
    var body: some View {
        VStack(spacing: 0) {
            NTTheme.deep
                .frame(height: NTLayout.topInset)
            Spacer(minLength: 0)
        }
        .edgesIgnoringSafeArea(.top)
        .allowsHitTesting(false)
    }
}

enum NTLayout {
    /// Screen width, read once — UIScreen is the iOS 15 safe way to do this.
    static var screenW: CGFloat { UIScreen.main.bounds.width }
    static var screenH: CGFloat { UIScreen.main.bounds.height }
    /// True on 375x667-class devices, where fixed hero layouts collapse.
    static var isCompact: Bool { UIScreen.main.bounds.height <= 700 }

    static var topInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            if let ws = scene as? UIWindowScene {
                for w in ws.windows where w.isKeyWindow {
                    return max(w.safeAreaInsets.top, 20)
                }
                if let first = ws.windows.first {
                    return max(first.safeAreaInsets.top, 20)
                }
            }
        }
        return 20
    }

    static var bottomInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            if let ws = scene as? UIWindowScene {
                for w in ws.windows where w.isKeyWindow {
                    return w.safeAreaInsets.bottom
                }
            }
        }
        return 0
    }

    /// The custom tab bar is a sibling of the content in a VStack, not an overlay, so
    /// scroll views only need ordinary breathing room at the bottom.
    static let tabBarHeight: CGFloat = 60
    static let scrollBottomPad: CGFloat = 28
}

// MARK: - Numeric safety

enum NTNum {
    /// Never let a NaN or an infinity reach the UI (pitfall #13).
    static func safeDiv(_ a: Double, _ b: Double, fallback: Double = 0) -> Double {
        guard b != 0, b.isFinite, a.isFinite else { return fallback }
        let r = a / b
        return r.isFinite ? r : fallback
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        if v.isNaN { return lo }
        return Swift.min(hi, Swift.max(lo, v))
    }

    static func clampF(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        if v.isNaN { return lo }
        return Swift.min(hi, Swift.max(lo, v))
    }

    /// Frequency formatted the way a piece of test gear would print it.
    static func hz(_ f: Double) -> String {
        guard f.isFinite, f > 0 else { return "—" }
        if f >= 10000 { return String(format: "%.1f kHz", f / 1000) }
        if f >= 1000 { return String(format: "%.2f kHz", f / 1000) }
        return String(format: "%.0f Hz", f)
    }

    static func hzShort(_ f: Double) -> String {
        guard f.isFinite, f > 0 else { return "—" }
        if f >= 1000 { return String(format: "%.1fk", f / 1000) }
        return String(format: "%.0f", f)
    }

    static func oneDecimal(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        return String(format: "%.1f", v)
    }

    static func signedDb(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        return String(format: "%@%.0f", v > 0 ? "+" : "", v)
    }
}

enum NTFormat {
    /// Pinned to en_US_POSIX so the UI cannot reorder with the phone's region (pitfall #12).
    static let dayLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy  HH:mm"
        return f
    }()

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    static func durationWords(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s) s" }
        let m = s / 60
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let rm = m % 60
        return rm == 0 ? "\(h) h" : "\(h) h \(rm) m"
    }

    /// Day key as yyyymmdd so dates compare as integers (pitfall #16).
    static func dayKey(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    /// Day key for the day `days` calendar days before today, so windows described to the
    /// user in days can be filtered by real dates rather than by a count of entries.
    static func dayKey(daysAgo days: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        let d = cal.date(byAdding: .day, value: -max(0, days), to: Date()) ?? Date()
        return dayKey(d)
    }

    static func date(fromDayKey key: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        var c = DateComponents()
        c.year = key / 10000
        c.month = (key / 100) % 100
        c.day = key % 100
        c.hour = 12
        return cal.date(from: c) ?? Date()
    }

    static func dayKeyLabel(_ key: Int) -> String {
        NTFormat.dayLabel.string(from: date(fromDayKey: key))
    }
}

import SwiftUI

// Every chart in Notch Tone is drawn in Canvas from computed numbers. No chart library,
// no images, and every curve is derived from the same coefficients the audio engine uses.

// MARK: - Spectrum model

enum NTSpectrumModel {

    static let minHz: Double = 40
    static let maxHz: Double = 16000
    static let bins = 168

    static func frequency(atFraction t: Double) -> Double {
        let lo = log2(minHz), hi = log2(maxHz)
        return pow(2.0, lo + NTNum.clamp(t, 0, 1) * (hi - lo))
    }

    static func fraction(ofFrequency f: Double) -> Double {
        let lo = log2(minHz), hi = log2(maxHz)
        let v = log2(NTNum.clamp(f, minHz, maxHz))
        return NTNum.safeDiv(v - lo, hi - lo)
    }

    /// Magnitude in decibels for one layer at one frequency, built from the same
    /// filter coefficients the render callback runs.
    private static func layerDb(_ cfg: NTLayerConfig, _ p: NTLayerParams, freq: Double, sr: Double) -> Double {
        if cfg.kind == .pureTone {
            // A tone is a line, handled separately by the drawing code.
            return -120
        }

        var db: Double
        switch cfg.colour {
        case .grey:
            var m = 1.0
            m *= NTFilterDesign.magnitude(p.g0, freq: freq, sampleRate: sr)
            m *= NTFilterDesign.magnitude(p.g1, freq: freq, sampleRate: sr)
            m *= NTFilterDesign.magnitude(p.g2, freq: freq, sampleRate: sr)
            db = 20 * log10(max(0.000001, m))
        default:
            let effective: NTNoiseColour = (cfg.kind == .modulatedBrown || cfg.kind == .fanBed) ? .brown : cfg.colour
            db = effective.slopePerOctave * log2(NTNum.clamp(freq, 1, 40000) / 1000.0)
        }

        var mag = 1.0
        switch cfg.kind {
        case .notchedNoise:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f1, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f2, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f3, freq: freq, sampleRate: sr)
        case .bandNoise:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f1, freq: freq, sampleRate: sr)
            mag *= 3.0
        case .modulatedBrown:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
        case .fanBed:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f1, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f2, freq: freq, sampleRate: sr)
        case .rainBed:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f1, freq: freq, sampleRate: sr)
            mag *= 2.4
        case .leavesBed:
            mag *= NTFilterDesign.magnitude(p.f0, freq: freq, sampleRate: sr)
            mag *= NTFilterDesign.magnitude(p.f1, freq: freq, sampleRate: sr)
            // The comb adds a shallow periodic ripple; shown as a small modulation.
            if p.combDelay > 1 {
                let delaySec = Double(p.combDelay) / sr
                mag *= (1.0 + 0.30 * cos(2.0 * Double.pi * freq * delaySec))
            }
        default:
            break
        }

        db += 20 * log10(max(0.000001, mag))
        db += 20 * log10(max(0.000001, NTNum.clamp(cfg.level, 0.0001, 1)))
        return db
    }

    /// Composite curve across all enabled layers, in decibels, one value per bin.
    /// Small preview charts ask for fewer bins so a scroll full of them stays cheap.
    static func curve(for layers: [NTLayerConfig], sampleRate: Double = 48000, bins: Int = NTSpectrumModel.bins) -> [Double] {
        let bins = max(16, bins)
        var out = [Double](repeating: -90, count: bins)
        let active = layers.filter { $0.enabled && $0.kind != .pureTone }
        guard !active.isEmpty else { return out }

        var built: [(NTLayerConfig, NTLayerParams)] = []
        for cfg in active {
            built.append((cfg, NTCoeffBuilder.build(cfg, gain: cfg.level, sampleRate: sampleRate)))
        }

        for i in 0..<bins {
            let t = Double(i) / Double(bins - 1)
            let f = frequency(atFraction: t)
            var power = 0.0
            for (cfg, p) in built {
                let db = layerDb(cfg, p, freq: f, sr: sampleRate)
                power += pow(10.0, NTNum.clamp(db, -120, 40) / 10.0)
            }
            out[i] = power > 0 ? 10 * log10(power) : -90
        }
        return out
    }

    /// Frequencies of any pure-tone layers, so the drawing can mark them.
    static func toneMarkers(for layers: [NTLayerConfig]) -> [Double] {
        layers.filter { $0.enabled && $0.kind == .pureTone }.map { $0.frequency }
    }

    static let gridFrequencies: [Double] = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    static func gridLabel(_ f: Double) -> String {
        f >= 1000 ? String(format: "%.0fk", f / 1000) : String(format: "%.0f", f)
    }
}

// MARK: - Spectrum view

struct NTSpectrumChart: View {
    let layers: [NTLayerConfig]
    /// Drawn as a vertical marker so the user can see where their tinnitus sits.
    let markerFrequency: Double?
    let height: CGFloat
    var showAxis: Bool = true
    var accent: Color = NTTheme.cyan
    var animatedPhase: Double = 0

    var body: some View {
        let curve = NTSpectrumModel.curve(for: layers, bins: showAxis ? NTSpectrumModel.bins : 72)
        let tones = NTSpectrumModel.toneMarkers(for: layers)

        Canvas { ctx, size in
            let w = size.width
            let plotH = max(10, size.height - (showAxis ? 16 : 0))
            let topDb: Double = 6
            let botDb: Double = -54

            func y(for db: Double) -> CGFloat {
                let t = NTNum.safeDiv(topDb - NTNum.clamp(db, botDb, topDb), topDb - botDb)
                return CGFloat(t) * plotH
            }

            // Graticule
            for f in NTSpectrumModel.gridFrequencies {
                let x = CGFloat(NTSpectrumModel.fraction(ofFrequency: f)) * w
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: plotH))
                ctx.stroke(p, with: .color(NTTheme.gridFaint), lineWidth: 1)
                if showAxis {
                    let text = Text(NTSpectrumModel.gridLabel(f))
                        .font(NTTheme.mono(8))
                        .foregroundColor(NTTheme.inkFaint)
                    // The graticule runs right to the canvas edge, so a centred label at the
                    // first or last line would be cut in half. Pull it back inside.
                    let labelX = NTNum.clampF(x, 12, max(12, w - 12))
                    ctx.draw(text, at: CGPoint(x: labelX, y: plotH + 8), anchor: .center)
                }
            }
            for i in 1..<5 {
                let yy = plotH * CGFloat(i) / 5
                var p = Path()
                p.move(to: CGPoint(x: 0, y: yy))
                p.addLine(to: CGPoint(x: w, y: yy))
                ctx.stroke(p, with: .color(NTTheme.gridFaint), lineWidth: 1)
            }

            guard curve.count > 1 else { return }

            // Filled spectrum
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: plotH))
            for i in 0..<curve.count {
                let x = w * CGFloat(i) / CGFloat(curve.count - 1)
                fill.addLine(to: CGPoint(x: x, y: y(for: curve[i])))
            }
            fill.addLine(to: CGPoint(x: w, y: plotH))
            fill.closeSubpath()
            ctx.fill(fill, with: .linearGradient(
                Gradient(colors: [accent.opacity(0.42), accent.opacity(0.06)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: plotH)))

            var line = Path()
            for i in 0..<curve.count {
                let x = w * CGFloat(i) / CGFloat(curve.count - 1)
                let pt = CGPoint(x: x, y: y(for: curve[i]))
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
            }
            ctx.stroke(line, with: .color(accent), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

            // Marker for the matched frequency, drawn on top of the notch it created.
            if let mf = markerFrequency, mf > 0 {
                let x = CGFloat(NTSpectrumModel.fraction(ofFrequency: mf)) * w
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: plotH))
                ctx.stroke(p, with: .color(NTTheme.amber.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                let dotR: CGFloat = 3.5
                ctx.fill(Path(ellipseIn: CGRect(x: x - dotR, y: -1, width: dotR * 2, height: dotR * 2)),
                         with: .color(NTTheme.amber))
            }

            // Pure tones drawn as solid vertical lines.
            for tf in tones {
                let x = CGFloat(NTSpectrumModel.fraction(ofFrequency: tf)) * w
                var p = Path()
                p.move(to: CGPoint(x: x, y: plotH * 0.12))
                p.addLine(to: CGPoint(x: x, y: plotH))
                ctx.stroke(p, with: .color(NTTheme.seriesLoud), lineWidth: 2)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Waveform strip

/// A live-feeling waveform derived from the generator parameters plus an animation phase.
/// It is an illustration of the configured sound, not a capture of the audio buffer.
struct NTWaveStrip: View {
    let layers: [NTLayerConfig]
    let phase: Double
    let level: Double
    let height: CGFloat
    var accent: Color = NTTheme.cyan

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let mid = h / 2
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: mid))
            baseline.addLine(to: CGPoint(x: w, y: mid))
            ctx.stroke(baseline, with: .color(NTTheme.gridFaint), lineWidth: 1)

            let active = layers.filter { $0.enabled }
            guard !active.isEmpty else {
                let text = Text("No layers").font(NTTheme.mono(10)).foregroundColor(NTTheme.inkFaint)
                ctx.draw(text, at: CGPoint(x: w / 2, y: mid), anchor: .center)
                return
            }

            // Deterministic pseudo-noise so the strip is stable rather than flickering.
            var rng = NTRandom(state: 0x5EED_1234)
            let steps = 150
            var path = Path()
            let amp = mid * 0.82 * CGFloat(NTNum.clamp(0.18 + level * 0.9, 0.1, 1))

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                var v = 0.0
                for cfg in active {
                    switch cfg.kind {
                    case .pureTone:
                        v += 0.9 * cfg.level * sin(t * 22.0 + phase * 2.0)
                    case .modulatedBrown, .fanBed:
                        let env = 0.55 + 0.45 * sin(t * 2.1 + phase)
                        v += cfg.level * env * (0.55 * sin(t * 9.0 + phase * 0.7) + 0.32 * rng.white())
                    case .rainBed:
                        let spark = rng.unit() < 0.12 ? 1.4 : 0.35
                        v += cfg.level * spark * rng.white()
                    case .leavesBed:
                        v += cfg.level * (0.5 * rng.white() + 0.28 * sin(t * 31.0 + phase * 1.5))
                    case .bandNoise:
                        v += cfg.level * 0.8 * sin(t * 26.0 + phase) * (0.6 + 0.4 * rng.unit())
                    default:
                        v += cfg.level * (0.75 * rng.white() + 0.2 * sin(t * 5.0 + phase))
                    }
                }
                v = NTNum.clamp(v / Double(max(1, active.count)), -1.4, 1.4)
                let x = w * CGFloat(t)
                let y = mid - CGFloat(v) * amp
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(accent.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
        }
        .frame(height: height)
    }
}

// MARK: - Level meter

struct NTLevelMeter: View {
    let level: Double
    let capFraction: Double
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let segments = 28
            let gap: CGFloat = 2
            let segW = (w - gap * CGFloat(segments - 1)) / CGFloat(segments)
            let lit = Int(NTNum.clamp(level, 0, 1) * Double(segments))
            let capIndex = Int(NTNum.clamp(capFraction, 0, 1) * Double(segments))
            for i in 0..<segments {
                let x = CGFloat(i) * (segW + gap)
                let rect = CGRect(x: x, y: 0, width: segW, height: h)
                var color = NTTheme.panelHigh
                if i < lit {
                    if i > capIndex { color = NTTheme.amber }
                    else if Double(i) / Double(segments) > 0.7 { color = NTTheme.seriesScore }
                    else { color = NTTheme.cyan }
                }
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Generic line chart

struct NTChartPoint: Identifiable {
    let id: Int
    let label: String
    let value: Double
}

struct NTLineChart: View {
    let points: [NTChartPoint]
    let minValue: Double
    let maxValue: Double
    let tint: Color
    let height: CGFloat
    var showDots: Bool = true
    var valueFormatter: (Double) -> String = { NTNum.oneDecimal($0) }

    var body: some View {
        Canvas { ctx, size in
            let leftPad: CGFloat = 34
            let bottomPad: CGFloat = 16
            let w = max(1, size.width - leftPad - 6)
            let h = max(1, size.height - bottomPad)
            let span = max(0.0001, maxValue - minValue)

            func y(_ v: Double) -> CGFloat {
                let t = NTNum.safeDiv(maxValue - NTNum.clamp(v, minValue, maxValue), span)
                return CGFloat(t) * h
            }

            for i in 0...4 {
                let yy = h * CGFloat(i) / 4
                var p = Path()
                p.move(to: CGPoint(x: leftPad, y: yy))
                p.addLine(to: CGPoint(x: leftPad + w, y: yy))
                ctx.stroke(p, with: .color(NTTheme.gridFaint), lineWidth: 1)
                let v = maxValue - span * Double(i) / 4
                let text = Text(valueFormatter(v)).font(NTTheme.mono(8)).foregroundColor(NTTheme.inkFaint)
                // The top gridline sits on y = 0, so a vertically centred label there would
                // have its upper half clipped away by the canvas.
                let labelY = NTNum.clampF(yy, 5, max(5, size.height - 5))
                ctx.draw(text, at: CGPoint(x: leftPad - 5, y: labelY), anchor: .trailing)
            }

            guard points.count > 0 else {
                let text = Text("No data yet").font(NTTheme.mono(10)).foregroundColor(NTTheme.inkFaint)
                ctx.draw(text, at: CGPoint(x: leftPad + w / 2, y: h / 2), anchor: .center)
                return
            }

            func x(_ i: Int) -> CGFloat {
                if points.count == 1 { return leftPad + w / 2 }
                return leftPad + w * CGFloat(i) / CGFloat(points.count - 1)
            }

            if points.count > 1 {
                var area = Path()
                area.move(to: CGPoint(x: x(0), y: h))
                for i in 0..<points.count { area.addLine(to: CGPoint(x: x(i), y: y(points[i].value))) }
                area.addLine(to: CGPoint(x: x(points.count - 1), y: h))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.30), tint.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))

                var line = Path()
                for i in 0..<points.count {
                    let pt = CGPoint(x: x(i), y: y(points[i].value))
                    if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
                }
                ctx.stroke(line, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }

            if showDots {
                for i in 0..<points.count {
                    let pt = CGPoint(x: x(i), y: y(points[i].value))
                    let r: CGFloat = points.count > 24 ? 1.8 : 3.0
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                             with: .color(tint))
                }
            }

            // Sparse x labels so they never collide.
            let step = max(1, points.count / 5)
            var i = 0
            while i < points.count {
                let text = Text(points[i].label).font(NTTheme.mono(8)).foregroundColor(NTTheme.inkFaint)
                ctx.draw(text, at: CGPoint(x: x(i), y: h + 8), anchor: .center)
                i += step
            }
        }
        .frame(height: height)
    }
}

// MARK: - Horizontal comparison bars

struct NTCompareBar: View {
    let leftValue: Double
    let rightValue: Double
    let maxValue: Double
    let leftTint: Color
    let rightTint: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let barH = (h - 6) / 2
            let lf = NTNum.clampF(CGFloat(NTNum.safeDiv(leftValue, maxValue)), 0, 1)
            let rf = NTNum.clampF(CGFloat(NTNum.safeDiv(rightValue, maxValue)), 0, 1)
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: max(2, w * lf), height: barH), cornerRadius: 3),
                     with: .color(leftTint))
            ctx.fill(Path(roundedRect: CGRect(x: 0, y: barH + 6, width: max(2, w * rf), height: barH), cornerRadius: 3),
                     with: .color(rightTint))
        }
        .frame(height: 22)
    }
}

// MARK: - Theme bar cluster (self-check breakdown)

struct NTThemeBars: View {
    let record: NTSelfCheckRecord

    var body: some View {
        VStack(spacing: 8) {
            ForEach(NTCheckTheme.allCases) { theme in
                let score = NTSelfCheck.themeScore(record, theme: theme)
                let maxScore = max(1, NTSelfCheck.themeMaximum(theme))
                HStack(spacing: 10) {
                    Text(theme.title)
                        .font(NTTheme.mono(11))
                        .foregroundColor(NTTheme.inkDim)
                        .frame(width: 96, alignment: .leading)
                    GeometryReader { geo in
                        let frac = NTNum.clampF(CGFloat(NTNum.safeDiv(Double(score), Double(maxScore))), 0, 1)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(NTTheme.panelHigh)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.tint)
                                .frame(width: max(3, geo.size.width * frac))
                        }
                    }
                    .frame(height: 8)
                    Text("\(score)/\(maxScore)")
                        .font(NTTheme.mono(11))
                        .foregroundColor(NTTheme.ink)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Frequency dial

/// A logarithmic frequency dial from 250 Hz to 12 kHz, drawn as a piece of test gear.
struct NTFrequencyDial: View {
    @Binding var frequency: Double
    let minHz: Double
    let maxHz: Double
    var onChange: ((Double) -> Void)? = nil
    var diameter: CGFloat = 220

    private func fraction(_ f: Double) -> Double {
        let lo = log2(minHz), hi = log2(maxHz)
        return NTNum.safeDiv(log2(NTNum.clamp(f, minHz, maxHz)) - lo, hi - lo)
    }

    private func hz(fromFraction t: Double) -> Double {
        let lo = log2(minHz), hi = log2(maxHz)
        return pow(2.0, lo + NTNum.clamp(t, 0, 1) * (hi - lo))
    }

    var body: some View {
        let sweep = 280.0
        let startAngle = 130.0

        ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                // The tick labels are drawn on a ring at r + 16 and Canvas clips to its
                // own bounds, so the track has to sit far enough in for that ring — plus
                // half a label — to stay inside the frame.
                let r = min(size.width, size.height) / 2 - 26

                var track = Path()
                track.addArc(center: c, radius: r,
                             startAngle: .degrees(startAngle),
                             endAngle: .degrees(startAngle + sweep), clockwise: false)
                ctx.stroke(track, with: .color(NTTheme.panelHigh), style: StrokeStyle(lineWidth: 12, lineCap: .round))

                // Octave graticule
                var f = 250.0
                while f <= maxHz + 1 {
                    let t = fraction(f)
                    let a = (startAngle + sweep * t) * Double.pi / 180
                    let inner = r - 10, outer = r + 6
                    var tick = Path()
                    tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                    tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer))
                    ctx.stroke(tick, with: .color(NTTheme.grid), lineWidth: 1.2)
                    let lt = Text(NTNum.hzShort(f)).font(NTTheme.mono(8)).foregroundColor(NTTheme.inkFaint)
                    ctx.draw(lt, at: CGPoint(x: c.x + CGFloat(cos(a)) * (r + 16),
                                             y: c.y + CGFloat(sin(a)) * (r + 16)), anchor: .center)
                    f *= 2
                }

                let t = fraction(frequency)
                var filled = Path()
                filled.addArc(center: c, radius: r,
                              startAngle: .degrees(startAngle),
                              endAngle: .degrees(startAngle + sweep * t), clockwise: false)
                ctx.stroke(filled, with: .color(NTTheme.cyan), style: StrokeStyle(lineWidth: 12, lineCap: .round))

                let a = (startAngle + sweep * t) * Double.pi / 180
                var pointer = Path()
                pointer.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - 34), y: c.y + CGFloat(sin(a)) * (r - 34)))
                pointer.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r + 2), y: c.y + CGFloat(sin(a)) * (r + 2)))
                ctx.stroke(pointer, with: .color(NTTheme.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

                let hub: CGFloat = 8
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - hub, y: c.y - hub, width: hub * 2, height: hub * 2)),
                         with: .color(NTTheme.panelEdge))
            }

            VStack(spacing: 2) {
                Text(NTNum.hz(frequency))
                    .font(NTTheme.mono(26, .semibold))
                    .foregroundColor(NTTheme.ink)
                Text("matched pitch")
                    .font(NTTheme.mono(9))
                    .foregroundColor(NTTheme.inkFaint)
                    .tracking(1.0)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let c = CGPoint(x: diameter / 2, y: diameter / 2)
                    let dx = Double(g.location.x - c.x)
                    let dy = Double(g.location.y - c.y)
                    guard dx * dx + dy * dy > 100 else { return }
                    var deg = atan2(dy, dx) * 180 / Double.pi
                    if deg < 0 { deg += 360 }
                    var rel = deg - startAngle
                    if rel < -40 { rel += 360 }
                    let t = NTNum.clamp(rel / sweep, 0, 1)
                    let nf = hz(fromFraction: t)
                    frequency = nf
                    onChange?(nf)
                }
        )
    }
}

import SwiftUI

// Every glyph in Notch Tone is drawn here. No SF Symbols, no emoji, no bundled art.
// Each glyph takes an explicit `size` so it can never inherit an ambiguous parent size.

// MARK: - Tab bar glyphs

/// Tab 1 — a waveform with a notch bitten out of its centre. The app's signature mark.
struct NTNotchWaveGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let w = size, h = size
            var path = Path()
            let steps = 44
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let x = t * Double(w)
                // Envelope with a gap in the middle third.
                let d = abs(t - 0.5)
                let gap = d < 0.11 ? 0.10 : 1.0
                let amp = 0.34 * Double(h) * gap * (0.55 + 0.45 * sin(t * .pi))
                let y = Double(h) * 0.5 - sin(t * .pi * 7.0) * amp
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(1.3, size * 0.075), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// Tab 2 — a dial with a pointer, the measurement mark.
struct NTDialGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let c = CGPoint(x: size / 2, y: size / 2)
            let r = size * 0.40
            let lw = max(1.3, size * 0.075)
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(140), endAngle: .degrees(400), clockwise: false)
            ctx.stroke(arc, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            var ptr = Path()
            ptr.move(to: c)
            ptr.addLine(to: CGPoint(x: c.x + cos(-.pi / 3) * r * 0.86, y: c.y + sin(-.pi / 3) * r * 0.86))
            ctx.stroke(ptr, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            let dotR = size * 0.055
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// Tab 3 — stacked log rows.
struct NTLogGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.2, size * 0.07)
            let inset = size * 0.14
            let rows = 4
            for i in 0..<rows {
                let y = inset + (size - inset * 2) * CGFloat(i) / CGFloat(rows - 1)
                var p = Path()
                p.move(to: CGPoint(x: inset, y: y))
                let widthFactor: CGFloat = [1.0, 0.72, 0.88, 0.55][i]
                p.addLine(to: CGPoint(x: inset + (size - inset * 2) * widthFactor, y: y))
                ctx.stroke(p, with: .color(color.opacity(i == 0 ? 1.0 : 0.72)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Tab 4 — an open reference card.
struct NTCardGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.2, size * 0.07)
            let inset = size * 0.13
            let rect = CGRect(x: inset, y: inset * 1.35, width: size - inset * 2, height: size - inset * 2.7)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: size * 0.10), with: .color(color), style: StrokeStyle(lineWidth: lw))
            var spine = Path()
            spine.move(to: CGPoint(x: size / 2, y: rect.minY + lw))
            spine.addLine(to: CGPoint(x: size / 2, y: rect.maxY - lw))
            ctx.stroke(spine, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: lw * 0.8))
        }
        .frame(width: size, height: size)
    }
}

/// Tab 5 — three sliders, an instrument's settings mark.
struct NTSlidersGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.2, size * 0.068)
            let inset = size * 0.15
            let cols = 3
            let knobPos: [CGFloat] = [0.34, 0.64, 0.46]
            for i in 0..<cols {
                let x = inset + (size - inset * 2) * CGFloat(i) / CGFloat(cols - 1)
                var p = Path()
                p.move(to: CGPoint(x: x, y: inset))
                p.addLine(to: CGPoint(x: x, y: size - inset))
                ctx.stroke(p, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                let ky = inset + (size - inset * 2) * knobPos[i]
                let kr = size * 0.085
                ctx.fill(Path(ellipseIn: CGRect(x: x - kr, y: ky - kr, width: kr * 2, height: kr * 2)), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Control glyphs

struct NTPlayGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            let inset = size * 0.22
            p.move(to: CGPoint(x: inset, y: inset * 0.82))
            p.addLine(to: CGPoint(x: size - inset * 0.9, y: size / 2))
            p.addLine(to: CGPoint(x: inset, y: size - inset * 0.82))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct NTPauseGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let barW = size * 0.16
            let h = size * 0.56
            let y = (size - h) / 2
            ctx.fill(Path(roundedRect: CGRect(x: size * 0.28 - barW / 2, y: y, width: barW, height: h), cornerRadius: barW * 0.35), with: .color(color))
            ctx.fill(Path(roundedRect: CGRect(x: size * 0.72 - barW / 2, y: y, width: barW, height: h), cornerRadius: barW * 0.35), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct NTStopGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let s = size * 0.44
            ctx.fill(Path(roundedRect: CGRect(x: (size - s) / 2, y: (size - s) / 2, width: s, height: s), cornerRadius: s * 0.18), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct NTChevronGlyph: View {
    let size: CGFloat
    let color: Color
    var rotation: Double = 0
    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            p.move(to: CGPoint(x: size * 0.38, y: size * 0.26))
            p.addLine(to: CGPoint(x: size * 0.66, y: size * 0.5))
            p.addLine(to: CGPoint(x: size * 0.38, y: size * 0.74))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.3, size * 0.085), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
    }
}

struct NTPlusGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.4, size * 0.10)
            let inset = size * 0.26
            var p = Path()
            p.move(to: CGPoint(x: inset, y: size / 2)); p.addLine(to: CGPoint(x: size - inset, y: size / 2))
            p.move(to: CGPoint(x: size / 2, y: inset)); p.addLine(to: CGPoint(x: size / 2, y: size - inset))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct NTCrossGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.3, size * 0.095)
            let inset = size * 0.30
            var p = Path()
            p.move(to: CGPoint(x: inset, y: inset)); p.addLine(to: CGPoint(x: size - inset, y: size - inset))
            p.move(to: CGPoint(x: size - inset, y: inset)); p.addLine(to: CGPoint(x: inset, y: size - inset))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct NTCheckGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            p.move(to: CGPoint(x: size * 0.26, y: size * 0.52))
            p.addLine(to: CGPoint(x: size * 0.44, y: size * 0.70))
            p.addLine(to: CGPoint(x: size * 0.75, y: size * 0.31))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.4, size * 0.11), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct NTWarnGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            var tri = Path()
            tri.move(to: CGPoint(x: size / 2, y: size * 0.10))
            tri.addLine(to: CGPoint(x: size * 0.94, y: size * 0.86))
            tri.addLine(to: CGPoint(x: size * 0.06, y: size * 0.86))
            tri.closeSubpath()
            ctx.stroke(tri, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, size * 0.09), lineJoin: .round))
            var bang = Path()
            bang.move(to: CGPoint(x: size / 2, y: size * 0.38))
            bang.addLine(to: CGPoint(x: size / 2, y: size * 0.62))
            ctx.stroke(bang, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, size * 0.09), lineCap: .round))
            let r = size * 0.045
            ctx.fill(Path(ellipseIn: CGRect(x: size / 2 - r, y: size * 0.71 - r, width: r * 2, height: r * 2)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct NTEarGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.2, size * 0.075)
            var p = Path()
            p.move(to: CGPoint(x: size * 0.62, y: size * 0.86))
            p.addCurve(to: CGPoint(x: size * 0.46, y: size * 0.58),
                       control1: CGPoint(x: size * 0.62, y: size * 0.72),
                       control2: CGPoint(x: size * 0.46, y: size * 0.70))
            p.addCurve(to: CGPoint(x: size * 0.70, y: size * 0.36),
                       control1: CGPoint(x: size * 0.46, y: size * 0.44),
                       control2: CGPoint(x: size * 0.70, y: size * 0.48))
            p.addCurve(to: CGPoint(x: size * 0.30, y: size * 0.30),
                       control1: CGPoint(x: size * 0.70, y: size * 0.10),
                       control2: CGPoint(x: size * 0.30, y: size * 0.08))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// A small spectrum bar cluster used as a decorative mark on cards.
struct NTBarsGlyph: View {
    let size: CGFloat
    let color: Color
    var heights: [CGFloat] = [0.4, 0.75, 0.55, 0.95, 0.3]
    var body: some View {
        Canvas { ctx, _ in
            let n = max(1, heights.count)
            let gap = size * 0.06
            let bw = (size - gap * CGFloat(n - 1)) / CGFloat(n)
            for i in 0..<n {
                let h = size * NTNum.clampF(heights[i], 0.08, 1.0) * 0.92
                let x = CGFloat(i) * (bw + gap)
                let rect = CGRect(x: x, y: size - h, width: bw, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: bw * 0.32), with: .color(color.opacity(0.55 + 0.45 * Double(i % 2))))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Tuning-fork mark used on measurement headers.
struct NTForkGlyph: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, _ in
            let lw = max(1.3, size * 0.085)
            var p = Path()
            p.move(to: CGPoint(x: size * 0.32, y: size * 0.12))
            p.addLine(to: CGPoint(x: size * 0.32, y: size * 0.50))
            p.addCurve(to: CGPoint(x: size * 0.68, y: size * 0.50),
                       control1: CGPoint(x: size * 0.32, y: size * 0.70),
                       control2: CGPoint(x: size * 0.68, y: size * 0.70))
            p.addLine(to: CGPoint(x: size * 0.68, y: size * 0.12))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            var stem = Path()
            stem.move(to: CGPoint(x: size * 0.5, y: size * 0.62))
            stem.addLine(to: CGPoint(x: size * 0.5, y: size * 0.90))
            ctx.stroke(stem, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// A drawn radio/checkbox marker.
struct NTSelectDot: View {
    let size: CGFloat
    let selected: Bool
    var tint: Color = NTTheme.cyan
    var body: some View {
        Canvas { ctx, _ in
            let r = size / 2 - 1
            let c = CGPoint(x: size / 2, y: size / 2)
            let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.stroke(ring, with: .color(selected ? tint : NTTheme.panelEdge), lineWidth: 1.4)
            if selected {
                let ir = r * 0.52
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - ir, y: c.y - ir, width: ir * 2, height: ir * 2)), with: .color(tint))
            }
        }
        .frame(width: size, height: size)
    }
}

/// A drawn toggle switch (the system Toggle is a system component and is not used).
struct NTToggleTrack: View {
    let on: Bool
    var tint: Color = NTTheme.cyan
    var body: some View {
        Canvas { ctx, size in
            let h = size.height
            let track = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: h), cornerRadius: h / 2)
            ctx.fill(track, with: .color(on ? tint.opacity(0.85) : NTTheme.panelHigh))
            ctx.stroke(track, with: .color(on ? tint : NTTheme.panelEdge), lineWidth: 1)
            let kr = h * 0.36
            let cx = on ? size.width - h / 2 : h / 2
            ctx.fill(Path(ellipseIn: CGRect(x: cx - kr, y: h / 2 - kr, width: kr * 2, height: kr * 2)),
                     with: .color(on ? NTTheme.deep : NTTheme.inkDim))
        }
        .frame(width: 48, height: 28)
    }
}

/// A labelled on/off row with a real tap target.
struct NTToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = NTTheme.cyan

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NTTheme.rounded(14, .medium))
                        .foregroundColor(NTTheme.ink)
                        .multilineTextAlignment(.leading)
                    if let s = subtitle {
                        Text(s)
                            .font(NTTheme.rounded(11))
                            .foregroundColor(NTTheme.inkFaint)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                NTToggleTrack(on: isOn, tint: tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Horizontal slider drawn by hand, with a graticule.
struct NTSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var ticks: Int = 8
    var tint: Color = NTTheme.cyan
    var onChanged: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let span = max(0.000001, range.upperBound - range.lowerBound)
            let frac = NTNum.clamp((value - range.lowerBound) / span, 0, 1)
            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    let midY = size.height / 2
                    let trackRect = CGRect(x: 0, y: midY - 3, width: size.width, height: 6)
                    ctx.fill(Path(roundedRect: trackRect, cornerRadius: 3), with: .color(NTTheme.panelHigh))
                    let fillRect = CGRect(x: 0, y: midY - 3, width: size.width * CGFloat(frac), height: 6)
                    ctx.fill(Path(roundedRect: fillRect, cornerRadius: 3), with: .color(tint.opacity(0.85)))
                    if ticks > 1 {
                        for i in 0...ticks {
                            let x = size.width * CGFloat(i) / CGFloat(ticks)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: midY + 7))
                            p.addLine(to: CGPoint(x: x, y: midY + 12))
                            ctx.stroke(p, with: .color(NTTheme.grid), lineWidth: 1)
                        }
                    }
                    let kx = NTNum.clampF(size.width * CGFloat(frac), 9, size.width - 9)
                    let kr: CGFloat = 9
                    ctx.fill(Path(ellipseIn: CGRect(x: kx - kr, y: midY - kr, width: kr * 2, height: kr * 2)), with: .color(tint))
                    ctx.fill(Path(ellipseIn: CGRect(x: kx - kr * 0.42, y: midY - kr * 0.42, width: kr * 0.84, height: kr * 0.84)), with: .color(NTTheme.deep))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = NTNum.clamp(Double(g.location.x / w), 0, 1)
                        let nv = range.lowerBound + f * span
                        value = nv
                        onChanged?(nv)
                    }
            )
        }
        .frame(height: 34)
    }
}

/// A row of segmented options drawn as pills.
struct NTSegmented: View {
    let options: [String]
    @Binding var index: Int
    var tint: Color = NTTheme.cyan

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<options.count, id: \.self) { i in
                Button(action: { index = i }) {
                    Text(options[i])
                        .font(NTTheme.mono(12, .medium))
                        .foregroundColor(i == index ? NTTheme.deep : NTTheme.inkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(i == index ? tint : NTTheme.panelHigh)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

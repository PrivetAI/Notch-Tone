import SwiftUI

/// A slider whose travel is logarithmic in frequency, so an octave always occupies
/// the same distance. Every frequency control in the app uses it.
struct NTLogFreqSlider: View {
    @Binding var frequency: Double
    var minHz: Double = 250
    var maxHz: Double = 12000
    var tint: Color = NTTheme.cyan
    var onChange: ((Double) -> Void)? = nil

    var body: some View {
        let lo = log2(minHz)
        let hi = log2(maxHz)
        let binding = Binding<Double>(
            get: { NTNum.safeDiv(log2(NTNum.clamp(frequency, minHz, maxHz)) - lo, hi - lo) },
            set: { t in
                let f = pow(2.0, lo + NTNum.clamp(t, 0, 1) * (hi - lo))
                frequency = f
                onChange?(f)
            })

        VStack(spacing: 2) {
            NTSlider(value: binding, range: 0...1, ticks: Int(max(1, (hi - lo).rounded())), tint: tint)
            HStack {
                Text(NTNum.hzShort(minHz))
                    .font(NTTheme.mono(9))
                    .foregroundColor(NTTheme.inkFaint)
                Spacer()
                Text(NTNum.hz(frequency))
                    .font(NTTheme.mono(13, .semibold))
                    .foregroundColor(NTTheme.ink)
                Spacer()
                Text(NTNum.hzShort(maxHz))
                    .font(NTTheme.mono(9))
                    .foregroundColor(NTTheme.inkFaint)
            }
        }
    }
}

/// A labelled parameter row: caption on the left, live value on the right, slider below.
struct NTParamRow<Control: View>: View {
    let label: String
    let value: String
    let control: Control

    init(label: String, value: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.value = value
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label.uppercased())
                    .font(NTTheme.mono(9, .semibold))
                    .foregroundColor(NTTheme.inkFaint)
                    .tracking(1.0)
                Spacer()
                Text(value)
                    .font(NTTheme.mono(12, .medium))
                    .foregroundColor(NTTheme.ink)
            }
            control
        }
    }
}

/// The noise-colour picker: six drawn swatches, each showing its own spectral slope.
struct NTColourPicker: View {
    @Binding var colour: NTNoiseColour
    var onChange: ((NTNoiseColour) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(NTNoiseColour.allCases, id: \.rawValue) { c in
                Button(action: {
                    colour = c
                    onChange?(c)
                }) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            NTSlopeGlyph(size: 16, slope: c.slopePerOctave,
                                         color: colour == c ? NTTheme.deep : NTTheme.cyan)
                            Text(c.title)
                                .font(NTTheme.rounded(12, .semibold))
                                .foregroundColor(colour == c ? NTTheme.deep : NTTheme.ink)
                        }
                        Text(c.slopeLabel)
                            .font(NTTheme.mono(9))
                            .foregroundColor(colour == c ? NTTheme.deep.opacity(0.75) : NTTheme.inkFaint)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colour == c ? NTTheme.cyan : NTTheme.panelHigh)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

/// A tiny sloped line that shows a noise colour's spectral tilt.
struct NTSlopeGlyph: View {
    let size: CGFloat
    let slope: Double
    let color: Color

    var body: some View {
        Canvas { ctx, _ in
            var p = Path()
            let t = NTNum.clampF(CGFloat(slope) / 6.0, -1, 1)
            let mid = size / 2
            p.move(to: CGPoint(x: size * 0.1, y: mid + t * size * 0.32))
            p.addLine(to: CGPoint(x: size * 0.9, y: mid - t * size * 0.32))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, size * 0.11), lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The stepper used by the loudness and masking ladders: a big minus, a readout, a big plus.
struct NTLadderStepper: View {
    let value: Double
    let unit: String
    var stepLabel: String = "1 dB steps"
    let onDown: () -> Void
    let onUp: () -> Void
    var atCeiling: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onDown) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NTTheme.panelHigh)
                    Canvas { ctx, size in
                        var p = Path()
                        p.move(to: CGPoint(x: size.width * 0.32, y: size.height / 2))
                        p.addLine(to: CGPoint(x: size.width * 0.68, y: size.height / 2))
                        ctx.stroke(p, with: .color(NTTheme.cyan), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    }
                }
                .frame(width: 62, height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            VStack(spacing: 2) {
                Text(String(format: "%.0f %@", value, unit))
                    .font(NTTheme.mono(22, .semibold))
                    .foregroundColor(atCeiling ? NTTheme.amber : NTTheme.ink)
                Text(stepLabel)
                    .font(NTTheme.mono(9))
                    .foregroundColor(NTTheme.inkFaint)
            }
            .frame(maxWidth: .infinity)

            Button(action: onUp) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(atCeiling ? NTTheme.amberDeep.opacity(0.5) : NTTheme.panelHigh)
                    NTPlusGlyph(size: 26, color: atCeiling ? NTTheme.amber : NTTheme.cyan)
                }
                .frame(width: 62, height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

/// A 0-10 tap scale used throughout the Diary.
struct NTScaleRow: View {
    @Binding var value: Int
    let tint: Color
    var lowLabel: String = ""
    var highLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0...10, id: \.self) { i in
                    Button(action: { value = i }) {
                        Text("\(i)")
                            .font(NTTheme.mono(12, i == value ? .bold : .regular))
                            .foregroundColor(i == value ? NTTheme.deep : NTTheme.inkDim)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(i == value ? tint : NTTheme.panelHigh)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            if !lowLabel.isEmpty || !highLabel.isEmpty {
                HStack {
                    Text(lowLabel)
                        .font(NTTheme.rounded(10))
                        .foregroundColor(NTTheme.inkFaint)
                    Spacer()
                    Text(highLabel)
                        .font(NTTheme.rounded(10))
                        .foregroundColor(NTTheme.inkFaint)
                }
            }
        }
    }
}

/// A drawn empty-state block. Every empty screen in the app uses one, with its own copy.
struct NTEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        NTPanel {
            VStack(alignment: .leading, spacing: 12) {
                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    var p = Path()
                    let steps = 60
                    for i in 0...steps {
                        let t = Double(i) / Double(steps)
                        let x = t * Double(w)
                        let y = Double(h) * 0.5 - sin(t * .pi * 2.2) * Double(h) * 0.22 * (1 - t * 0.6)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(p, with: .color(NTTheme.panelEdge),
                               style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 4]))
                }
                .frame(height: 46)

                Text(title)
                    .font(NTTheme.rounded(16, .semibold))
                    .foregroundColor(NTTheme.ink)
                Text(message)
                    .font(NTTheme.rounded(13))
                    .foregroundColor(NTTheme.inkDim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let t = actionTitle, let a = action {
                    Button(action: a) {
                        NTButtonLabel(title: t, filled: false, tint: NTTheme.cyan, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

/// A metric readout tile: a big number with a caption, used across Measure and Diary.
struct NTStatTile: View {
    let caption: String
    let value: String
    var detail: String? = nil
    var tint: Color = NTTheme.cyan

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption.uppercased())
                .font(NTTheme.mono(9, .semibold))
                .foregroundColor(NTTheme.inkFaint)
                .tracking(1.0)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(NTTheme.mono(19, .semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let d = detail {
                Text(d)
                    .font(NTTheme.rounded(10))
                    .foregroundColor(NTTheme.inkFaint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NTTheme.panelHigh))
    }
}

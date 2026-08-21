import SwiftUI

/// Shown for the fraction of a second the launch check takes. Drawn entirely in Canvas:
/// a spectrum band with the app's signature notch opening in the middle.
struct NTLoadingScreen: View {
    @State private var ntPhase: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [NTTheme.deep, NTTheme.panel],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 0)

                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    let bars = 34
                    let gap: CGFloat = 4
                    let bw = (w - gap * CGFloat(bars - 1)) / CGFloat(bars)
                    for i in 0..<bars {
                        let t = Double(i) / Double(bars - 1)
                        let d = abs(t - 0.5)
                        // The notch: a band of the spectrum removed in the centre.
                        let gate = d < 0.10 ? 0.08 : 1.0
                        let wave = 0.35 + 0.45 * abs(sin(t * 3.4 + ntPhase))
                        let barH = CGFloat(wave * gate) * h
                        let x = CGFloat(i) * (bw + gap)
                        let rect = CGRect(x: x, y: (h - barH) / 2, width: bw, height: max(2, barH))
                        let colour = d < 0.10 ? NTTheme.amber.opacity(0.55) : NTTheme.cyan.opacity(0.55 + 0.45 * wave)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: bw / 2), with: .color(colour))
                    }
                }
                .frame(width: min(300, NTLayout.screenW - 60), height: 118)

                VStack(spacing: 8) {
                    Text("NOTCH TONE")
                        .font(NTTheme.mono(19, .semibold))
                        .tracking(4)
                        .foregroundColor(NTTheme.ink)
                    Text("Sound built around your own measurement")
                        .font(NTTheme.rounded(13))
                        .foregroundColor(NTTheme.inkDim)
                }

                Spacer(minLength: 0)

                Text("Not a medical device. Not a hearing test.")
                    .font(NTTheme.rounded(11))
                    .foregroundColor(NTTheme.inkFaint)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: true)) {
                ntPhase = 3.14159
            }
        }
    }
}

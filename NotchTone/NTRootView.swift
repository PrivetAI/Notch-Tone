import SwiftUI

// MARK: - Shared screen scaffolding
//
// Every screen in the app scrolls inside this container, so the top safe area and the
// floating tab bar are handled in exactly one place.

struct NTScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            NTTheme.deep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(NTTheme.rounded(26, .bold))
                            .foregroundColor(NTTheme.ink)
                        if let s = subtitle {
                            Text(s)
                                .font(NTTheme.rounded(13))
                                .foregroundColor(NTTheme.inkDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 2)

                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, NTLayout.scrollBottomPad)
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
    }
}

/// A pushed screen: same scaffold plus a drawn back control.
struct NTDetailScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let content: Content
    @Environment(\.presentationMode) private var presentationMode

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            NTTheme.deep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 6) {
                            NTChevronGlyph(size: 16, color: NTTheme.cyan, rotation: 180)
                            Text("Back")
                                .font(NTTheme.rounded(14, .medium))
                                .foregroundColor(NTTheme.cyan)
                        }
                        .padding(.vertical, 6)
                        .padding(.trailing, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(NTTheme.rounded(24, .bold))
                            .foregroundColor(NTTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let s = subtitle {
                            Text(s)
                                .font(NTTheme.rounded(13))
                                .foregroundColor(NTTheme.inkDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, NTLayout.scrollBottomPad)
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
    }
}

// MARK: - Root

struct NTRootView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth

    @State private var selectedTab: Int = 0
    @State private var showOnboarding: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            NTTheme.deep.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationView { NTSoundView(selectedTab: $selectedTab) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { NTMeasureView(selectedTab: $selectedTab) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { NTDiaryView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 3:
                        NavigationView { NTLearnView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { NTSettingsView(showOnboarding: $showOnboarding) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }

            // Painted last so scrolled content can never draw over the clock.
            NTStatusStrip()
        }
        .sheet(isPresented: $showOnboarding) {
            NTOnboardingView(isPresented: $showOnboarding)
                .environmentObject(store)
        }
        .onAppear(perform: bootstrap)
        .onChange(of: selectedTab) { newValue in
            // Leaving the Measure tab mid-procedure must always restore the sound stack.
            if newValue != 1 {
                synth.endMeasurementMode()
            }
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NTTheme.panelEdge)
                .frame(height: 1)
            HStack(spacing: 0) {
                tabButton(0, "Sound", AnyView(NTNotchWaveGlyph(size: 22, color: tint(0))))
                tabButton(1, "Measure", AnyView(NTDialGlyph(size: 22, color: tint(1))))
                tabButton(2, "Diary", AnyView(NTLogGlyph(size: 22, color: tint(2))))
                tabButton(3, "Learn", AnyView(NTCardGlyph(size: 22, color: tint(3))))
                tabButton(4, "Settings", AnyView(NTSlidersGlyph(size: 22, color: tint(4))))
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(NTTheme.panel.edgesIgnoringSafeArea(.bottom))
        }
    }

    private func tint(_ index: Int) -> Color {
        selectedTab == index ? NTTheme.cyan : NTTheme.inkFaint
    }

    private func tabButton(_ index: Int, _ label: String, _ icon: AnyView) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            VStack(spacing: 4) {
                icon
                Text(label)
                    .font(NTTheme.rounded(10, selectedTab == index ? .semibold : .regular))
                    .foregroundColor(tint(index))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func bootstrap() {
        synth.outputCap = store.settings.outputCap
        synth.fadeSeconds = store.settings.fadeSeconds
        synth.endFadeSeconds = store.settings.endFadeSeconds
        synth.allowBackground = store.settings.keepPlayingInBackground
        synth.masterLevel = store.settings.lastMasterLevel
        let idx = min(max(0, store.settings.defaultTimerIndex), NTSleepTimer.options.count - 1)
        synth.timerMinutes = NTSleepTimer.options[idx]

        synth.onSessionFinished = { [weak store] log in
            store?.addSession(log)
        }

        if synth.layers.isEmpty {
            // The stack the user left behind comes back first; only a genuinely fresh
            // install falls through to the authored starting preset.
            let saved = store.settings.lastLayers
            if !saved.isEmpty {
                synth.setLayers(saved)
            } else {
                let presets = NTPresetLibrary.builtIn(profileFrequency: store.profile.matchedFrequency)
                if let first = presets.first(where: { $0.name == "Notch, Standard" }) ?? presets.first {
                    synth.setLayers(first.resolvedLayers(profileFrequency: store.profile.matchedFrequency))
                }
            }
        }

        // Wired after the restore so replaying the saved stack does not schedule a write.
        synth.onStackChanged = { [weak store] layers in
            guard let store = store else { return }
            if store.settings.lastLayers != layers { store.settings.lastLayers = layers }
        }

        if !store.settings.hasSeenOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showOnboarding = true
            }
        }
    }
}

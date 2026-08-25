import SwiftUI

enum NTSettingsSheet: Identifiable {
    case privacy
    case safety

    var id: Int {
        switch self {
        case .privacy: return 0
        case .safety: return 1
        }
    }
}

private enum NTResetKind {
    case profile
    case diary
    case checks
    case everything
}

struct NTSettingsView: View {
    @EnvironmentObject private var store: NTStore
    @EnvironmentObject private var synth: NTSynth
    @Binding var showOnboarding: Bool

    @State private var sheet: NTSettingsSheet? = nil
    @State private var pendingReset: NTResetKind? = nil
    @State private var showResetAlert: Bool = false

    var body: some View {
        NTScreen(title: "Settings",
                 subtitle: "Output limits, session defaults, safety information and your data.") {

            outputSection
            sessionSection
            displaySection
            safetySection
            dataSection
            aboutSection
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .privacy:
                NTWebPanel(ntAddress: "https://tabletoprails.org/click.php")
                    .edgesIgnoringSafeArea(.bottom)   // never .all
            case .safety:
                NTVolumeWarningView(isPresented: Binding(get: { sheet != nil },
                                                        set: { if !$0 { sheet = nil } }),
                                    onAccept: {},
                                    showAcceptButton: false)
            }
        }
        .alert(isPresented: $showResetAlert) {
            resetAlert
        }
    }

    // MARK: - Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Output",
                            caption: "The app's own ceiling. Your device volume and headphones still set the final level.")

            NTPanel {
                VStack(alignment: .leading, spacing: 16) {
                    NTParamRow(label: "Master volume cap",
                               value: String(format: "%.0f%%", store.settings.outputCap / 0.60 * 100)) {
                        NTSlider(value: Binding(get: { store.settings.outputCap },
                                                set: { v in
                                                    store.settings.outputCap = v
                                                    synth.outputCap = v
                                                    synth.publishMaster()
                                                }),
                                 range: 0.06...0.60, ticks: 9, tint: NTTheme.cyan)
                    }
                    Text("Everything the app plays is scaled to sit under this ceiling, so even the level slider at one hundred percent cannot exceed it. Lowering it is always safe; there is no reason to raise it unless the sound is genuinely inaudible at a sensible device volume.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)

                    NTParamRow(label: "Fade in",
                               value: String(format: "%.2f s", store.settings.fadeSeconds)) {
                        NTSlider(value: Binding(get: { store.settings.fadeSeconds },
                                                set: { v in
                                                    store.settings.fadeSeconds = v
                                                    synth.fadeSeconds = v
                                                }),
                                 range: 0.15...1.5, ticks: 6, tint: NTTheme.cyanDim)
                    }
                    Text("Every sound ramps up over this time so nothing ever starts with a click or a blast. The default of three tenths of a second is gentle and barely noticeable.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    NTSafetyNote(text: "The cap protects you from the app. It cannot protect you from your device volume — set that low before you start, in a quiet room.")
                }
            }
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Sessions")

            NTPanel {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("DEFAULT SLEEP TIMER")
                            .font(NTTheme.mono(9, .semibold))
                            .foregroundColor(NTTheme.inkFaint)
                            .tracking(1.0)
                        HStack(spacing: 6) {
                            ForEach(0..<NTSleepTimer.options.count, id: \.self) { i in
                                Button(action: {
                                    store.settings.defaultTimerIndex = i
                                    synth.setTimer(minutes: NTSleepTimer.options[i])
                                }) {
                                    Text(NTSleepTimer.label(NTSleepTimer.options[i]))
                                        .font(NTTheme.mono(11, .medium))
                                        .foregroundColor(store.settings.defaultTimerIndex == i ? NTTheme.deep : NTTheme.inkDim)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(store.settings.defaultTimerIndex == i ? NTTheme.cyan : NTTheme.panelHigh)
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    NTParamRow(label: "End-of-session fade",
                               value: NTFormat.durationWords(Int(store.settings.endFadeSeconds))) {
                        NTSlider(value: Binding(get: { store.settings.endFadeSeconds },
                                                set: { v in
                                                    store.settings.endFadeSeconds = v.rounded()
                                                    synth.endFadeSeconds = store.settings.endFadeSeconds
                                                }),
                                 range: 10...180, ticks: 6, tint: NTTheme.cyanDim)
                    }
                    Text("A timed session fades out slowly over this window rather than stopping abruptly, which is far less likely to wake you.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)

                    NTToggleRow(title: "Keep playing when the screen locks",
                                subtitle: "On by default, so a sleep session survives the phone locking or you switching apps. Turn it off and playback stops the moment the app goes to the background.",
                                isOn: Binding(get: { store.settings.keepPlayingInBackground },
                                              set: { v in
                                                  store.settings.keepPlayingInBackground = v
                                                  synth.allowBackground = v
                                              }))
                }
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Display")
            NTPanel {
                VStack(alignment: .leading, spacing: 14) {
                    NTToggleRow(title: "Large level readout",
                                subtitle: "Shows the master level as a big numeral with a segmented meter on the Sound tab.",
                                isOn: Binding(get: { store.settings.showLevelReadout },
                                              set: { v in store.settings.showLevelReadout = v }))

                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)

                    Button(action: { showOnboarding = true }) {
                        settingsRow(title: "Re-open the introduction",
                                    detail: "The six-page explainer shown on first run.")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Safety

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Safety and disclaimer",
                            caption: "Permanently reachable, exactly as it appeared before your first session.")

            NTPanel(tint: NTTheme.amber.opacity(0.4)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        NTWarnGlyph(size: 20, color: NTTheme.amber)
                        Text("Volume safety")
                            .font(NTTheme.rounded(16, .bold))
                            .foregroundColor(NTTheme.amber)
                        Spacer(minLength: 0)
                    }
                    Text("Sudden or sustained loud sound can make tinnitus worse. Start quiet, never raise the level past comfortable, and do not mask at high volume.")
                        .font(NTTheme.rounded(13))
                        .foregroundColor(NTTheme.inkDim)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { sheet = .safety }) {
                        NTButtonLabel(title: "Read the full safety information", filled: false,
                                      tint: NTTheme.amber, compact: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            NTPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Medical disclaimer")
                        .font(NTTheme.rounded(16, .semibold))
                        .foregroundColor(NTTheme.ink)
                    disclaimerLine("Notch Tone is not a medical device. It does not diagnose, treat, cure or prevent anything, and nothing in it is medical advice.")
                    disclaimerLine("The pitch match is a self-matching exercise, not an audiometric hearing test. It cannot measure hearing loss.")
                    disclaimerLine("Every level shown is a relative in-app value, not dB SL or dB HL. A phone and consumer headphones have no calibrated output.")
                    disclaimerLine("The severity self-check was written for this app. It is not a published clinical instrument and produces no clinical score.")
                    disclaimerLine("Please consult an audiologist or a physician about your tinnitus — especially if it is sudden, one-sided or pulsatile, or comes with hearing loss or dizziness.")
                    disclaimerLine("Diary correlations are associations within your own log. They are not evidence of cause.")
                }
            }
        }
    }

    private func disclaimerLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Rectangle()
                .fill(NTTheme.cyanDim)
                .frame(width: 2, height: 13)
                .cornerRadius(1)
                .padding(.top, 4)
            Text(text)
                .font(NTTheme.rounded(12))
                .foregroundColor(NTTheme.inkDim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "Your data",
                            caption: "Everything is stored on this device only. There are no accounts and nothing is uploaded.")

            NTPanel(padding: 0) {
                VStack(spacing: 0) {
                    dataRow(title: "Reset the measured profile",
                            detail: "\(store.pitchRecords.count) pitch, \(store.loudnessRecords.count) loudness and \(store.maskingRecords.count) masking record\(store.maskingRecords.count == 1 ? "" : "s")",
                            tint: NTTheme.amber) {
                        pendingReset = .profile
                        showResetAlert = true
                    }
                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                    dataRow(title: "Delete the self-check history",
                            detail: "\(store.selfChecks.count) completed check\(store.selfChecks.count == 1 ? "" : "s")",
                            tint: NTTheme.amber) {
                        pendingReset = .checks
                        showResetAlert = true
                    }
                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                    dataRow(title: "Delete the diary",
                            detail: "\(store.diary.count) entr\(store.diary.count == 1 ? "y" : "ies") and \(store.sessions.count) logged session\(store.sessions.count == 1 ? "" : "s")",
                            tint: NTTheme.amber) {
                        pendingReset = .diary
                        showResetAlert = true
                    }
                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1).padding(.leading, 14)
                    dataRow(title: "Reset everything",
                            detail: "Profile, diary, self-checks, saved presets, reading progress and settings",
                            tint: NTTheme.amber) {
                        pendingReset = .everything
                        showResetAlert = true
                    }
                }
            }
        }
    }

    private func dataRow(title: String, detail: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NTTheme.rounded(14, .medium))
                        .foregroundColor(tint)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(NTTheme.rounded(11))
                        .foregroundColor(NTTheme.inkFaint)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                NTChevronGlyph(size: 14, color: NTTheme.inkFaint)
                    .padding(.top, 3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var resetAlert: Alert {
        switch pendingReset {
        case .profile:
            return Alert(title: Text("Reset the measured profile?"),
                         message: Text("Your matched pitch, loudness and masking records will be deleted. The diary, self-checks and saved presets are not affected. This cannot be undone."),
                         primaryButton: .destructive(Text("Reset")) { store.resetProfile() },
                         secondaryButton: .cancel(Text("Keep")))
        case .checks:
            return Alert(title: Text("Delete the self-check history?"),
                         message: Text("Every completed self-check will be removed, including the trend chart built from them. This cannot be undone."),
                         primaryButton: .destructive(Text("Delete")) { store.resetSelfChecks() },
                         secondaryButton: .cancel(Text("Keep")))
        case .diary:
            return Alert(title: Text("Delete the diary?"),
                         message: Text("Every daily entry, factor tag and logged listening session will be removed, and the correlation view will start from nothing. This cannot be undone."),
                         primaryButton: .destructive(Text("Delete")) { store.resetDiary() },
                         secondaryButton: .cancel(Text("Keep")))
        case .everything:
            return Alert(title: Text("Reset everything?"),
                         message: Text("This deletes your profile, diary, self-checks, saved presets, reading progress and settings. The app returns to the state it was in when you installed it. This cannot be undone."),
                         primaryButton: .destructive(Text("Reset everything")) {
                             synth.stop(logSession: false)
                             store.resetEverything()
                             synth.outputCap = store.settings.outputCap
                             synth.fadeSeconds = store.settings.fadeSeconds
                             synth.endFadeSeconds = store.settings.endFadeSeconds
                             synth.allowBackground = store.settings.keepPlayingInBackground
                             synth.masterLevel = store.settings.lastMasterLevel
                             let idx = min(max(0, store.settings.defaultTimerIndex),
                                           NTSleepTimer.options.count - 1)
                             synth.setTimer(minutes: NTSleepTimer.options[idx])
                             synth.setLayers(NTPresetLibrary.builtIn(profileFrequency: nil).first?.layers ?? [])
                         },
                         secondaryButton: .cancel(Text("Cancel")))
        case .none:
            return Alert(title: Text("Nothing selected"),
                         message: Text("No action was chosen."),
                         dismissButton: .cancel(Text("Close")))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NTSectionHeader(title: "About")

            NTPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        NTNotchWaveGlyph(size: 30, color: NTTheme.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notch Tone")
                                .font(NTTheme.rounded(18, .bold))
                                .foregroundColor(NTTheme.ink)
                            Text("Version 1.0")
                                .font(NTTheme.mono(11))
                                .foregroundColor(NTTheme.inkFaint)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("Every sound in this app is synthesised in code by an AVAudioEngine source node running a hand-written filter chain — cascaded band-reject sections for the notch, a seven-pole chain for pink, a leaky integrator for brown, band-pass pairs for the beds. There are no audio files in the bundle at all.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The Learn library holds \(NTLearn.all.count) authored cards. The self-check, the factor set, the presets and every word of the library were written for this app.")
                        .font(NTTheme.rounded(12))
                        .foregroundColor(NTTheme.inkDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle().fill(NTTheme.gridFaint).frame(height: 1)

                    Button(action: { sheet = .privacy }) {
                        settingsRow(title: "Privacy Policy",
                                    detail: "Opens in an in-app browser.")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Text("Notch Tone is a self-management and sound-generation tool. It is not a medical device.")
                .font(NTTheme.rounded(11))
                .foregroundColor(NTTheme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }

    private func settingsRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NTTheme.rounded(14, .medium))
                    .foregroundColor(NTTheme.ink)
                Text(detail)
                    .font(NTTheme.rounded(11))
                    .foregroundColor(NTTheme.inkFaint)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            NTChevronGlyph(size: 14, color: NTTheme.cyan)
                .padding(.top, 3)
        }
        .contentShape(Rectangle())
    }
}

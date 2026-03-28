import SwiftUI
import AVFoundation

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dsTheme) private var theme

    private let audio = AudioCueService.shared
    @State private var vibrateOnSpeech: Bool = AudioCueService.shared.vibrateOnSpeech

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("cadence")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .tracking(4)
                                .textCase(.uppercase)
                                .foregroundStyle(theme.primary)
                            Text("Settings")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.textPrimary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Settings rows
                VStack(spacing: DSSpacing.sm) {
                    NavigationLink {
                        VoiceSettingsView()
                    } label: {
                        settingsRow(
                            icon: "waveform",
                            title: "Coaching Voice",
                            detail: audio.voice?.name ?? "None"
                        )
                    }
                    .buttonStyle(.plain)

                    // Vibrate toggle
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.body)
                            .foregroundStyle(theme.primary)
                            .frame(width: 28, height: 28)

                        Text("Vibrate on Voice Cues")
                            .font(.body)
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Toggle("", isOn: $vibrateOnSpeech)
                            .labelsHidden()
                            .tint(theme.primary)
                            .onChange(of: vibrateOnSpeech) { _, newValue in
                                audio.vibrateOnSpeech = newValue
                            }
                    }
                    .padding(.vertical, DSSpacing.md)
                    .padding(.horizontal, DSSpacing.lg)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                }
                .padding(.horizontal, 16)
            }
        }
        .background(DSColors.background)
    }

    private func settingsRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(theme.primary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, DSSpacing.md)
        .padding(.horizontal, DSSpacing.lg)
        .background(DSColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    }
}

// MARK: - VoiceSettingsView

struct VoiceSettingsView: View {
    @Environment(\.dsTheme) private var theme

    @State private var voices: [AudioCueService.VoiceInfo] = []
    @State private var selectedID: String?
    @State private var previewingID: String?
    @State private var previewSynthesizer: AVSpeechSynthesizer?

    private let audio = AudioCueService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Current voice info
                if let current = voices.first(where: { $0.isSelected }) {
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.name)
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            Text(current.quality)
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(DSSpacing.lg)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .padding(.horizontal, 16)
                    .padding(.top, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.lg)
                }

                // Voice list
                if voices.isEmpty {
                    Text("No voices available")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 16)
                } else {
                    voiceList
                }

                // Download button
                DSButton(
                    title: "Download More Voices",
                    icon: "arrow.up.right.square",
                    variant: .secondary,
                    size: .md
                ) {
                    if let url = URL(string: "App-prefs:ACCESSIBILITY&path=SPEECH_TITLE") {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.xxxl)
            }
        }
        .background(DSColors.background)
        .navigationTitle("Coaching Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
    }

    // MARK: - Voice List

    private var voiceList: some View {
        let grouped = Dictionary(grouping: voices) { $0.quality }
        let order = ["Premium", "Enhanced", "Siri", "Default", "Compact", "Super Compact"]
        let sortedKeys = order.filter { grouped[$0] != nil }

        return LazyVStack(spacing: 0) {
            ForEach(sortedKeys, id: \.self) { tier in
                VStack(alignment: .leading, spacing: 0) {
                    // Tier header
                    HStack(spacing: DSSpacing.sm) {
                        Text(tier)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.primary)
                            .textCase(.uppercase)
                            .tracking(1)

                        qualityBadge(for: tier)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, DSSpacing.lg)
                    .padding(.bottom, DSSpacing.sm)

                    // Voices in tier
                    ForEach(grouped[tier]!) { voice in
                        voiceRow(voice)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func qualityBadge(for tier: String) -> some View {
        switch tier {
        case "Premium", "Enhanced":
            badgePill("Best", color: theme.success)
        case "Siri":
            badgePill("Good", color: theme.primary)
        default:
            EmptyView()
        }
    }

    private func badgePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func voiceRow(_ voiceInfo: AudioCueService.VoiceInfo) -> some View {
        Button {
            selectedID = voiceInfo.id
            audio.preferredVoiceID = voiceInfo.id
            refresh()
        } label: {
            HStack {
                Text(voiceInfo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                // Preview button
                Button {
                    preview(voiceInfo)
                } label: {
                    Image(systemName: previewingID == voiceInfo.id ? "speaker.wave.2.fill" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(theme.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Selected checkmark
                if voiceInfo.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, DSSpacing.md)
            .background(
                voiceInfo.isSelected
                    ? theme.primary.opacity(0.08)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func refresh() {
        voices = audio.availableVoices()
        selectedID = voices.first(where: { $0.isSelected })?.id
    }

    private func preview(_ voiceInfo: AudioCueService.VoiceInfo) {
        // Stop any existing preview
        previewSynthesizer?.stopSpeaking(at: .immediate)

        previewingID = voiceInfo.id

        let synth = AVSpeechSynthesizer()
        previewSynthesizer = synth
        let utterance = AVSpeechUtterance(string: "Let's get going. Next up, bench press.")
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceInfo.id)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        synth.speak(utterance)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if previewingID == voiceInfo.id {
                previewingID = nil
            }
        }
    }
}

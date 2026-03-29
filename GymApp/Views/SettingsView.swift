import SwiftUI
import AVFoundation

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dsTheme) private var theme

    private let audio = AudioCueService.shared
    @State private var userName: String = UserDefaults.standard.string(forKey: "Settings.userName") ?? ""
    @State private var voiceEnabled: Bool = AudioCueService.shared.voiceEnabled
    @State private var vibrateOnSpeech: Bool = AudioCueService.shared.vibrateOnSpeech
    @State private var countdownSeconds: Int = UserDefaults.standard.object(forKey: "Settings.countdownSeconds") != nil
        ? UserDefaults.standard.integer(forKey: "Settings.countdownSeconds") : 3
    @State private var healthKitEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "Settings.healthKitEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "Settings.healthKitEnabled")
    }()

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
                    // Name
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: "person")
                            .font(.body)
                            .foregroundStyle(theme.primary)
                            .frame(width: 28, height: 28)

                        TextField("Your name", text: $userName)
                            .font(.body)
                            .foregroundStyle(theme.textPrimary)
                            .onChange(of: userName) { _, newValue in
                                let trimmed = String(newValue.prefix(100))
                                if trimmed != newValue {
                                    userName = trimmed
                                }
                                UserDefaults.standard.set(trimmed, forKey: "Settings.userName")
                            }
                    }
                    .padding(.vertical, DSSpacing.md)
                    .padding(.horizontal, DSSpacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Voice coaching toggle
                    settingsToggle(
                        icon: "speaker.wave.2",
                        title: "Voice Coaching",
                        isOn: $voiceEnabled
                    ) { newValue in
                        audio.voiceEnabled = newValue
                    }

                    // Coaching voice picker (only if voice enabled)
                    if voiceEnabled {
                        NavigationLink {
                            VoiceSettingsView()
                        } label: {
                            settingsRow(
                                icon: "waveform",
                                title: "Coaching Voice",
                                detail: audio.voice?.name ?? "None"
                            )
                        }
                        .buttonStyle(.tactile)
                    }

                    // Vibrate toggle
                    settingsToggle(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Vibrate on Voice Cues",
                        isOn: $vibrateOnSpeech
                    ) { newValue in
                        audio.vibrateOnSpeech = newValue
                    }

                    // Countdown setting
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: "timer")
                            .font(.body)
                            .foregroundStyle(theme.primary)
                            .frame(width: 28, height: 28)

                        Text("Countdown")
                            .font(.body)
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Picker("", selection: $countdownSeconds) {
                            Text("Off").tag(0)
                            Text("3s").tag(3)
                            Text("10s").tag(10)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        .onChange(of: countdownSeconds) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "Settings.countdownSeconds")
                        }
                    }
                    .padding(.vertical, DSSpacing.md)
                    .padding(.horizontal, DSSpacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Apple Health toggle
                    settingsToggle(
                        icon: "heart.fill",
                        title: "Apple Health",
                        isOn: $healthKitEnabled
                    ) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "Settings.healthKitEnabled")
                    }
                }
                .padding(.horizontal, 16)

                // About
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("About")
                        .font(DSFont.captionBold.font)
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Text("Your workout data, preferences, and history are stored locally on your device. AI features run entirely on-device with no third-party services. Apple Health integration is optional and stays local. We may use anonymized analytics to improve the app, but your personal information is not shared or sold.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, DSSpacing.xxl)
                .padding(.bottom, DSSpacing.xxxl)
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func settingsToggle(icon: String, title: String, isOn: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(theme.primary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.primary)
                .onChange(of: isOn.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
        }
        .padding(.vertical, DSSpacing.md)
        .padding(.horizontal, DSSpacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - VoiceSettingsView

struct VoiceSettingsView: View {
    @Environment(\.dsTheme) private var theme

    @State private var voices: [AudioCueService.VoiceInfo] = []
    @State private var selectedID: String?

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
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.lg)
                }

                // Recommendation
                Text("We recommend Ava (Premium) for the most natural coaching experience. You can download it in Settings → Accessibility → Spoken Content → Voices → English.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, DSSpacing.md)

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
                    if let url = URL(string: "App-prefs:ACCESSIBILITY") {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, DSSpacing.lg)

                Text("You can also find voices in Settings → Accessibility → Live Speech → Voices")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, DSSpacing.sm)
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
        case "Premium":
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
        .buttonStyle(.tactile)
    }

    // MARK: - Actions

    private func refresh() {
        voices = audio.availableVoices()
        selectedID = voices.first(where: { $0.isSelected })?.id
    }

}

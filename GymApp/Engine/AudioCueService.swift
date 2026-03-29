import Foundation
import AVFoundation
import UIKit

// MARK: - AudioCueService

final class AudioCueService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioCueService()

    private let synthesizer = AVSpeechSynthesizer()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    /// Active voice used for speech
    private(set) var voice: AVSpeechSynthesisVoice?

    /// True when the resolved voice is low-quality (compact, eloquence, or missing)
    var needsVoiceUpgrade: Bool {
        guard let id = voice?.identifier else { return true }
        return !(id.contains("premium") || id.contains("enhanced") || id.contains("siri"))
    }

    /// Whether the audio session is currently activated for speech
    private var sessionActive = false

    /// UserDefaults key for dismissing the voice upgrade prompt
    private static let voicePromptDismissedKey = "AudioCueService.voicePromptDismissed"
    private static let preferredVoiceKey = "AudioCueService.preferredVoiceID"
    private static let vibrateOnSpeechKey = "AudioCueService.vibrateOnSpeech"
    private static let voiceEnabledKey = "AudioCueService.voiceEnabled"

    /// Whether the user has already dismissed the voice upgrade prompt
    var voicePromptDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: Self.voicePromptDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.voicePromptDismissedKey) }
    }

    /// True when we should show the voice upgrade prompt
    var shouldPromptForVoiceUpgrade: Bool {
        needsVoiceUpgrade && !voicePromptDismissed
    }

    /// Whether voice coaching is enabled
    var voiceEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.voiceEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.voiceEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.voiceEnabledKey) }
    }

    /// Whether to vibrate when speech begins
    var vibrateOnSpeech: Bool {
        get { UserDefaults.standard.bool(forKey: Self.vibrateOnSpeechKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.vibrateOnSpeechKey) }
    }

    /// The user's preferred voice identifier, if set
    var preferredVoiceID: String? {
        get { UserDefaults.standard.string(forKey: Self.preferredVoiceKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.preferredVoiceKey)
            reloadVoice()
        }
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        reloadVoice()
    }

    /// Reloads the active voice from user preference or auto-selection.
    func reloadVoice() {
        if let savedID = UserDefaults.standard.string(forKey: Self.preferredVoiceKey),
           let saved = AVSpeechSynthesisVoice(identifier: savedID) {
            voice = saved
        } else {
            voice = Self.resolveVoice()
        }
    }

    // MARK: - Available Voices

    struct VoiceInfo: Identifiable {
        let id: String // identifier
        let name: String
        let quality: String
        let isSelected: Bool
    }

    /// Returns all en-US voices grouped and sorted by quality tier.
    /// Filters out novelty/eloquence voices (Bells, Boing, etc.)
    func availableVoices() -> [VoiceInfo] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" && !$0.identifier.contains("eloquence") && !$0.identifier.contains("speech.synthesis") }
            .sorted { tierRank($0.identifier) < tierRank($1.identifier) }

        let currentID = voice?.identifier
        return allVoices.map { v in
            VoiceInfo(
                id: v.identifier,
                name: v.name,
                quality: tierLabel(v.identifier),
                isSelected: v.identifier == currentID
            )
        }
    }

    private func tierRank(_ identifier: String) -> Int {
        if identifier.contains("premium") { return 0 }
        if identifier.contains("enhanced") { return 1 }
        if identifier.contains("siri") { return 2 }
        if identifier.contains("compact") { return 3 }
        if identifier.contains("eloquence") { return 5 }
        return 4
    }

    private func tierLabel(_ identifier: String) -> String {
        if identifier.contains("premium") { return "Premium" }
        if identifier.contains("enhanced") { return "Enhanced" }
        if identifier.contains("siri") { return "Siri" }
        if identifier.contains("super-compact") { return "Super Compact" }
        if identifier.contains("compact") { return "Compact" }
        if identifier.contains("eloquence") { return "Eloquence" }
        return "Default"
    }

    // MARK: - Voice Selection

    /// Picks the most natural-sounding female en-US voice available on this device.
    /// Falls back through premium → enhanced → default quality tiers.
    private static func resolveVoice() -> AVSpeechSynthesisVoice? {
        let available = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        let availableIDs = Set(available.map(\.identifier))

        // Preferred voices, best quality first.
        // premium = most natural (must be downloaded)
        // enhanced = good (must be downloaded)
        // siri = high quality, often pre-installed
        // compact = passable (often pre-installed)
        // eloquence = awful robotic legacy voices — avoid at all costs
        let preferredIDs = [
            // Premium
            "com.apple.voice.premium.en-US.Ava",
            "com.apple.voice.premium.en-US.Zoe",
            "com.apple.voice.premium.en-US.Samantha",
            // Enhanced
            "com.apple.voice.enhanced.en-US.Ava",
            "com.apple.voice.enhanced.en-US.Zoe",
            "com.apple.voice.enhanced.en-US.Samantha",
            // Compact (still decent, often pre-installed)
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.voice.super-compact.en-US.Samantha",
        ]

        for id in preferredIDs {
            if availableIDs.contains(id) {
                return AVSpeechSynthesisVoice(identifier: id)
            }
        }

        // Try Siri voices — high quality and often pre-installed
        if let siri = available.first(where: { $0.identifier.contains("siri") }) {
            return siri
        }

        // Last resort — any en-US voice that isn't an eloquence voice
        let nonEloquence = available.first { voice in
            !voice.identifier.contains("eloquence")
        }
        return nonEloquence ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Audio Session

    /// Call once when the workout starts — configures the category but does NOT
    /// keep the session permanently active (ducking is managed per-utterance).
    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
        } catch {
            print("AudioCueService: failed to configure session — \(error)")
        }
    }

    func deactivate() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateSession()
    }

    private func activateSession() {
        guard !sessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            sessionActive = true
        } catch {
            print("AudioCueService: failed to activate session — \(error)")
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        } catch {
            print("AudioCueService: failed to deactivate session — \(error)")
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateSession()
    }

    // MARK: - Speech

    func speak(_ text: String, urgency: Urgency = .normal) {
        // Triple-tap pulse if enabled (fires even if voice is off)
        if vibrateOnSpeech {
            impactHeavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
                impactHeavy.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [self] in
                impactHeavy.impactOccurred()
            }
        }

        guard voiceEnabled else { return }

        // Stop any in-progress utterance so cues don't queue up
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Activate session (ducks music) right before speaking
        activateSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice

        switch urgency {
        case .low:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
        case .normal:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.9
        case .high:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
            utterance.pitchMultiplier = 1.05
            utterance.volume = 1.0
        }

        synthesizer.speak(utterance)
    }

    // MARK: - Haptics

    func hapticTick() {
        impactLight.impactOccurred()
    }

    func hapticPulse() {
        impactMedium.impactOccurred()
    }

    func hapticAlert() {
        impactHeavy.impactOccurred()
    }

    func hapticSuccess() {
        notification.notificationOccurred(.success)
    }

    func hapticWarning() {
        notification.notificationOccurred(.warning)
    }

    // MARK: - Urgency

    enum Urgency {
        case low, normal, high
    }
}

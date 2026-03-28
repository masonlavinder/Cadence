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

    /// Resolved voice — best available female en-US voice
    private let voice: AVSpeechSynthesisVoice?

    /// Whether the audio session is currently activated for speech
    private var sessionActive = false

    private override init() {
        self.voice = Self.resolveVoice()
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voice Selection

    /// Picks the most natural-sounding female en-US voice available on this device.
    /// Falls back through premium → enhanced → default quality tiers.
    private static func resolveVoice() -> AVSpeechSynthesisVoice? {
        let available = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        let availableIDs = Set(available.map(\.identifier))

        // Preferred voices, best quality first
        let preferredIDs = [
            "com.apple.voice.premium.en-US.Ava",
            "com.apple.voice.premium.en-US.Zoe",
            "com.apple.voice.enhanced.en-US.Ava",
            "com.apple.voice.enhanced.en-US.Zoe",
            "com.apple.voice.enhanced.en-US.Samantha",
        ]

        for id in preferredIDs {
            if availableIDs.contains(id) {
                return AVSpeechSynthesisVoice(identifier: id)
            }
        }

        // Fall back to any en-US voice — but skip compact/super-compact if possible
        let nonCompact = available.first { id in
            !id.identifier.contains("compact")
        }
        return nonCompact ?? AVSpeechSynthesisVoice(language: "en-US")
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

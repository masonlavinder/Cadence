import Foundation
import AVFoundation

// MARK: - AudioCueService
// TODO Phase 3: Implement TTS and haptics service
// - Singleton: AudioCueService.shared
// - Configures AVAudioSession with .playback category, .voicePrompt mode
// - Uses AVSpeechSynthesizer for TTS with three urgency levels
// - Fires UIImpactFeedbackGenerator haptics alongside speech

/// Placeholder for AudioCueService
/// See Phase 3 in GymApp-ClaudeCode-Plan.md for full implementation details
final class AudioCueService {
    static let shared = AudioCueService()
    
    private init() {
        // TODO: Implement in Phase 3
    }
    
    func speak(_ text: String) {
        // TODO: Implement in Phase 3
    }
    
    func activate() {
        // TODO: Configure AVAudioSession
    }
    
    func deactivate() {
        // TODO: Deactivate AVAudioSession
    }
}

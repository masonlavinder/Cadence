//
//  ChatService.swift
//  Cadence
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
@Observable
final class ChatService {
    enum State: Equatable {
        case idle
        case responding
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private(set) var messages: [ChatMessage] = []

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    private let model = SystemLanguageModel.default
    #endif

    init() {
        print("Coach: init — checking availability")
        checkAvailability()
    }

    func checkAvailability() {
        #if targetEnvironment(simulator)
        print("Coach: running on simulator — Apple Intelligence not supported")
        state = .unavailable("Apple Intelligence requires a physical device. Please run on an iPhone or iPad to use Coach.")
        return
        #endif

        #if canImport(FoundationModels)
        let availability = model.availability
        print("Coach: FoundationModels imported, model.availability = \(availability)")
        switch availability {
        case .available:
            print("Coach: model is available ✅")
            state = .idle
            createSession()
            return
        case .unavailable(let reason):
            print("Coach: model unavailable — reason: \(reason)")
            switch reason {
            case .deviceNotEligible:
                state = .unavailable("This device doesn't support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                state = .unavailable("Enable Apple Intelligence in Settings to use Coach.")
            case .modelNotReady:
                state = .unavailable("Apple Intelligence is still setting up. Try again later.")
            @unknown default:
                state = .unavailable("Apple Intelligence is not available.")
            }
            return
        default:
            print("Coach: model availability fell through default case")
            break
        }
        #else
        print("Coach: FoundationModels NOT available (canImport failed)")
        #endif
        state = .unavailable("Apple Intelligence is not available on this device.")
    }

    func send(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        let placeholderID = UUID()
        let placeholder = ChatMessage(id: placeholderID, role: .assistant, content: "")
        messages.append(placeholder)
        state = .responding

        #if canImport(FoundationModels)
        // Prefix the user text with the coaching context so the model
        // understands its role even without a separate system instruction.
        let prompt = """
            You are a friendly fitness coach. The user asks:
            \(text)
            Give a concise, practical answer.
            """

        for attempt in 1...2 {
            do {
                if session == nil { createSession() }
                guard let currentSession = session else { break }

                // Use streaming for more reliable responses
                var accumulated = ""
                let stream = currentSession.streamResponse(to: prompt)
                for try await partial in stream {
                    accumulated = partial.content
                    updateAssistant(id: placeholderID, with: accumulated)
                }

                if !accumulated.isEmpty {
                    state = .idle
                    return
                }
                // Empty response — fall through to retry
                print("Coach: attempt \(attempt) returned empty response")
                session = nil
                createSession()
            } catch {
                print("Coach: attempt \(attempt) failed — \(error)")
                session = nil
                createSession()
            }
        }

        // Check if the error is a model catalog / asset issue
        updateAssistant(
            id: placeholderID,
            with: "The on-device AI model isn't ready yet. Make sure Apple Intelligence is fully set up in Settings > Apple Intelligence & Siri. The device may need to be on Wi-Fi, plugged in, and locked for models to finish downloading."
        )
        #else
        updateAssistant(id: placeholderID, with: "Apple Intelligence is not available in this build.")
        #endif

        state = .idle
    }

    func resetConversation() {
        messages.removeAll()
        #if canImport(FoundationModels)
        session = nil
        createSession()
        #endif
    }

    // MARK: - Private

    #if canImport(FoundationModels)
    private func createSession() {
        print("Coach: creating new LanguageModelSession (no instructions)")
        session = LanguageModelSession()
        print("Coach: session created — \(session != nil ? "success" : "nil")")
    }
    #endif

    private func updateAssistant(id: UUID, with content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
        }
    }
}

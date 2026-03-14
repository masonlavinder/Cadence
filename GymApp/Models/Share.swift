import Foundation
import SwiftData

/// Share entity for workout sharing functionality (future feature)
/// Allows users to share workouts via links or codes
@Model
final class Share: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Workout Reference
    /// UUID of the workout being shared
    /// NOT a @Relationship — allows workout to be deleted without breaking share links
    var workoutId: UUID
    
    /// Denormalized workout name for display
    var workoutName: String
    
    // MARK: - Share Configuration
    var shareType: ShareType
    var status: ShareStatus
    
    // MARK: - Access Control
    var shareCode: String  // Unique code or URL slug
    var expiresAt: Date?
    var maxUses: Int?  // Nil = unlimited
    var currentUses: Int
    
    // MARK: - Recipient Info (for direct shares)
    var recipientUserId: String?  // Future: user ID from auth system
    var recipientEmail: String?
    
    // MARK: - Metadata
    var sharedByUserId: String?  // Future: current user's ID
    var lastAccessedAt: Date?
    
    // MARK: - Initialization
    init(
        workoutId: UUID,
        workoutName: String,
        shareType: ShareType = .link,
        shareCode: String,
        expiresAt: Date? = nil,
        maxUses: Int? = nil
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.shareType = shareType
        self.status = .active
        self.shareCode = shareCode
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.currentUses = 0
        self.recipientUserId = nil
        self.recipientEmail = nil
        self.sharedByUserId = nil
        self.lastAccessedAt = nil
    }
    
    // MARK: - Computed Properties
    
    /// Check if the share is still valid
    var isValid: Bool {
        guard status == .active else { return false }
        
        // Check expiration
        if let expiresAt = expiresAt, Date() > expiresAt {
            return false
        }
        
        // Check max uses
        if let maxUses = maxUses, currentUses >= maxUses {
            return false
        }
        
        return true
    }
    
    /// Generate a shareable URL or code display string
    var displayCode: String {
        switch shareType {
        case .link:
            return "https://gymapp.link/\(shareCode)"
        case .directSend:
            return "Direct share to \(recipientEmail ?? "user")"
        case .publicListing:
            return "Public listing: \(shareCode)"
        }
    }
}

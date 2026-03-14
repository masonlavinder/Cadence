import Foundation

/// Base protocol for all SwiftData models in GymApp
/// Provides common timestamp fields and utility methods
protocol BaseEntity {
    var id: UUID { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
}

extension BaseEntity {
    /// Updates the updatedAt timestamp to now
    mutating func touch() {
        updatedAt = Date()
    }
}

/// Helper function to generate base field values for new entities
/// Returns (id, createdAt, updatedAt) tuple
func newBaseFields() -> (UUID, Date, Date) {
    let now = Date()
    return (UUID(), now, now)
}

import Foundation

// MARK: - Devotional Message Entity (Domain Layer)
// Mensaje diario de un usuario en un devocional

struct DevotionalMessageEntity: Identifiable, Equatable {
    let id: String?
    let devotionalId: String
    let dayNumber: Int // Día del devocional (1-7)
    let userId: String
    let userName: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let isEdited: Bool
    
    init(
        id: String? = nil,
        devotionalId: String,
        dayNumber: Int,
        userId: String,
        userName: String,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isEdited: Bool = false
    ) {
        self.id = id
        self.devotionalId = devotionalId
        self.dayNumber = dayNumber
        self.userId = userId
        self.userName = userName
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEdited = isEdited
    }
}

import Foundation
import FirebaseFirestore

// MARK: - Devotional Message Data Model (Data Layer)

struct DevotionalMessageDataModel: Codable {
    @DocumentID var id: String?
    var devotionalId: String
    var dayNumber: Int
    var userId: String
    var userName: String
    var content: String
    var createdAt: Timestamp
    var updatedAt: Timestamp
    var isEdited: Bool
    
    init(
        id: String? = nil,
        devotionalId: String,
        dayNumber: Int,
        userId: String,
        userName: String,
        content: String,
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp(),
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

// MARK: - Mapper: Data Model <-> Domain Entity

extension DevotionalMessageDataModel {
    func toDomain() -> DevotionalMessageEntity {
        DevotionalMessageEntity(
            id: id,
            devotionalId: devotionalId,
            dayNumber: dayNumber,
            userId: userId,
            userName: userName,
            content: content,
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue(),
            isEdited: isEdited
        )
    }
    
    static func fromDomain(_ entity: DevotionalMessageEntity) -> DevotionalMessageDataModel {
        DevotionalMessageDataModel(
            id: entity.id,
            devotionalId: entity.devotionalId,
            dayNumber: entity.dayNumber,
            userId: entity.userId,
            userName: entity.userName,
            content: entity.content,
            createdAt: Timestamp(date: entity.createdAt),
            updatedAt: Timestamp(date: entity.updatedAt),
            isEdited: entity.isEdited
        )
    }
}

import Foundation
import FirebaseFirestore

// MARK: - Team Data Model (Data Layer)
// Modelo de datos específico para Firestore

struct TeamDataModel: Codable {
    @DocumentID var id: String?
    var name: String
    var code: String
    var leaderId: String
    var leaderName: String
    var memberIds: [String]
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    init(id: String? = nil,
         name: String,
         code: String,
         leaderId: String,
         leaderName: String,
         memberIds: [String] = [],
         createdAt: Timestamp = Timestamp(),
         updatedAt: Timestamp = Timestamp()) {
        self.id = id
        self.name = name
        self.code = code
        self.leaderId = leaderId
        self.leaderName = leaderName
        self.memberIds = memberIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapper: Data Model <-> Domain Entity

extension TeamDataModel {
    func toDomain() -> TeamEntity {
        TeamEntity(
            id: id,
            name: name,
            code: code,
            leaderId: leaderId,
            leaderName: leaderName,
            memberIds: memberIds,
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue()
        )
    }
    
    static func fromDomain(_ entity: TeamEntity) -> TeamDataModel {
        TeamDataModel(
            id: entity.id,
            name: entity.name,
            code: entity.code,
            leaderId: entity.leaderId,
            leaderName: entity.leaderName,
            memberIds: entity.memberIds,
            createdAt: Timestamp(date: entity.createdAt),
            updatedAt: Timestamp(date: entity.updatedAt)
        )
    }
}


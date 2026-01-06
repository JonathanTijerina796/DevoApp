import Foundation

// MARK: - Team Entity (Domain Layer)
// Entidad pura del dominio, sin dependencias de frameworks

struct TeamEntity: Identifiable, Equatable {
    let id: String?
    let name: String
    let code: String
    let leaderId: String
    let leaderName: String
    let memberIds: [String]
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String? = nil,
         name: String,
         code: String,
         leaderId: String,
         leaderName: String,
         memberIds: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
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


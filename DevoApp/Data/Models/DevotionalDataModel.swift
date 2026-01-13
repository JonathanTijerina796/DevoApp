import Foundation
import FirebaseFirestore

// MARK: - Devotional Data Model (Data Layer)
// Modelo de datos específico para Firestore

struct DevotionalDataModel: Codable {
    @DocumentID var id: String?
    var teamId: String
    var title: String
    var startDate: Timestamp
    var endDate: Timestamp
    var dailyInstructions: [DailyInstructionData]
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    init(
        id: String? = nil,
        teamId: String,
        title: String,
        startDate: Timestamp,
        endDate: Timestamp,
        dailyInstructions: [DailyInstructionData] = [],
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp()
    ) {
        self.id = id
        self.teamId = teamId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.dailyInstructions = dailyInstructions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DailyInstructionData: Codable {
    var id: Int
    var date: Timestamp
    var instruction: String
    var passage: String?
}

// MARK: - Mapper: Data Model <-> Domain Entity

extension DevotionalDataModel {
    func toDomain() -> DevotionalEntity {
        DevotionalEntity(
            id: id,
            teamId: teamId,
            title: title,
            startDate: startDate.dateValue(),
            endDate: endDate.dateValue(),
            dailyInstructions: dailyInstructions.map { $0.toDomain() },
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue()
        )
    }
    
    static func fromDomain(_ entity: DevotionalEntity) -> DevotionalDataModel {
        DevotionalDataModel(
            id: entity.id,
            teamId: entity.teamId,
            title: entity.title,
            startDate: Timestamp(date: entity.startDate),
            endDate: Timestamp(date: entity.endDate),
            dailyInstructions: entity.dailyInstructions.map { DailyInstructionData.fromDomain($0) },
            createdAt: Timestamp(date: entity.createdAt),
            updatedAt: Timestamp(date: entity.updatedAt)
        )
    }
}

extension DailyInstructionData {
    func toDomain() -> DailyInstruction {
        DailyInstruction(
            id: id,
            date: date.dateValue(),
            instruction: instruction,
            passage: passage
        )
    }
    
    static func fromDomain(_ entity: DailyInstruction) -> DailyInstructionData {
        DailyInstructionData(
            id: entity.id,
            date: Timestamp(date: entity.date),
            instruction: entity.instruction,
            passage: entity.passage
        )
    }
}

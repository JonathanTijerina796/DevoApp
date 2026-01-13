import Foundation

// MARK: - Create Devotional Use Case
// Crea un devocional con tema específico (solo para líderes)

protocol CreateDevotionalUseCaseProtocol {
    func execute(
        teamId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        dailyInstructions: [DailyInstruction]
    ) async throws -> DevotionalEntity
}

final class CreateDevotionalUseCase: CreateDevotionalUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    private let teamRepository: TeamRepositoryProtocol
    
    init(
        devotionalRepository: DevotionalRepositoryProtocol,
        teamRepository: TeamRepositoryProtocol
    ) {
        self.devotionalRepository = devotionalRepository
        self.teamRepository = teamRepository
    }
    
    func execute(
        teamId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        dailyInstructions: [DailyInstruction]
    ) async throws -> DevotionalEntity {
        // Validar que el equipo existe
        guard let _ = try await teamRepository.getTeamById(teamId) else {
            throw DevotionalError.devotionalNotFound
        }
        
        // Validar que hay 7 instrucciones
        guard dailyInstructions.count == 7 else {
            throw NSError(domain: "CreateDevotionalUseCase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Debe haber exactamente 7 instrucciones diarias"])
        }
        
        // Validar que las fechas son válidas
        guard endDate > startDate else {
            throw NSError(domain: "CreateDevotionalUseCase", code: -1, userInfo: [NSLocalizedDescriptionKey: "La fecha de fin debe ser posterior a la fecha de inicio"])
        }
        
        // Crear devocional
        let devotional = DevotionalEntity(
            teamId: teamId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            dailyInstructions: dailyInstructions
        )
        
        return try await devotionalRepository.createDevotional(devotional)
    }
}

import Foundation

// MARK: - Create Default Devotional Use Case
// Crea un devocional por defecto con tema libre cuando se crea un equipo

protocol CreateDefaultDevotionalUseCaseProtocol {
    func execute(teamId: String, teamName: String) async throws -> DevotionalEntity
}

final class CreateDefaultDevotionalUseCase: CreateDefaultDevotionalUseCaseProtocol {
    private let devotionalRepository: DevotionalRepositoryProtocol
    
    init(devotionalRepository: DevotionalRepositoryProtocol) {
        self.devotionalRepository = devotionalRepository
    }
    
    func execute(teamId: String, teamName: String) async throws -> DevotionalEntity {
        let calendar = Calendar.current
        let today = Date()
        
        // Calcular fecha de inicio (hoy) y fin (7 días después)
        let startDate = calendar.startOfDay(for: today)
        guard let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) else {
            throw NSError(domain: "CreateDefaultDevotionalUseCase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al calcular fechas"])
        }
        
        // Crear instrucciones genéricas para cada día (tema libre)
        var dailyInstructions: [DailyInstruction] = []
        for day in 1...7 {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startDate) {
                dailyInstructions.append(DailyInstruction(
                    id: day,
                    date: dayDate,
                    instruction: NSLocalizedString("free_topic_instruction", comment: ""),
                    passage: nil
                ))
            }
        }
        
        // Crear devocional por defecto
        let devotional = DevotionalEntity(
            teamId: teamId,
            title: teamName, // Usar el nombre del equipo como título
            startDate: startDate,
            endDate: endDate,
            dailyInstructions: dailyInstructions
        )
        
        // Guardar en Firestore
        return try await devotionalRepository.createDevotional(devotional)
    }
}

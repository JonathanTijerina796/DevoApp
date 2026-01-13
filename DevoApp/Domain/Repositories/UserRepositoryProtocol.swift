import Foundation

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol {
    func getUserById(_ userId: String) async throws -> UserEntity?
    func updateUser(_ user: UserEntity) async throws
    func getUserTeamId(_ userId: String) async throws -> String? // Mantener para compatibilidad
    func setUserTeam(userId: String, teamId: String, role: UserRole) async throws // Mantener para compatibilidad
    func removeUserTeam(userId: String) async throws // Mantener para compatibilidad
    
    // Nuevos métodos para múltiples equipos
    func getUserTeams(_ userId: String) async -> [UserTeam]
    func addUserTeam(userId: String, teamId: String, role: UserRole) async throws
    func removeUserTeam(userId: String, teamId: String) async throws
    func setSelectedTeam(userId: String, teamId: String) async throws
    func getSelectedTeamId(_ userId: String) async -> String?
}


import Foundation

// MARK: - Team Repository Protocol
// Dependency Inversion Principle: Dependemos de abstracciones, no de implementaciones concretas

protocol TeamRepositoryProtocol {
    func createTeam(name: String, leaderId: String, leaderName: String) async throws -> TeamEntity
    func findTeamByCode(_ code: String) async throws -> TeamEntity?
    func getTeamById(_ teamId: String) async throws -> TeamEntity?
    func updateTeam(_ team: TeamEntity) async throws
    func addMemberToTeam(teamId: String, memberId: String) async throws
    func removeMemberFromTeam(teamId: String, memberId: String) async throws
    func deleteTeam(_ teamId: String) async throws
    func generateUniqueTeamCode() async throws -> String
    func checkCodeExists(_ code: String) async throws -> Bool
}


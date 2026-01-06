import Foundation

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol {
    func getUserById(_ userId: String) async throws -> UserEntity?
    func updateUser(_ user: UserEntity) async throws
    func getUserTeamId(_ userId: String) async throws -> String?
    func setUserTeam(userId: String, teamId: String, role: UserRole) async throws
    func removeUserTeam(userId: String) async throws
}


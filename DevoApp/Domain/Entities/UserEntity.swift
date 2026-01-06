import Foundation

// MARK: - User Entity (Domain Layer)

struct UserEntity: Identifiable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let teamId: String?
    let role: UserRole?
    let createdAt: Date?
    let updatedAt: Date?
}

enum UserRole: String, Codable {
    case leader
    case member
}


import Foundation
import FirebaseFirestore

// MARK: - User Repository Implementation

final class UserRepository: UserRepositoryProtocol {
    private let db: Firestore
    private let usersCollection = "users"
    
    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }
    
    func getUserById(_ userId: String) async throws -> UserEntity? {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return UserEntity(
            id: userId,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String,
            firstName: data["firstName"] as? String,
            lastName: data["lastName"] as? String,
            teamId: data["teamId"] as? String,
            role: (data["role"] as? String).flatMap { UserRole(rawValue: $0) },
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
    
    func updateUser(_ user: UserEntity) async throws {
        var data: [String: Any] = [
            "email": user.email,
            "updatedAt": Timestamp()
        ]
        
        if let displayName = user.displayName {
            data["displayName"] = displayName
        }
        if let firstName = user.firstName {
            data["firstName"] = firstName
        }
        if let lastName = user.lastName {
            data["lastName"] = lastName
        }
        if let teamId = user.teamId {
            data["teamId"] = teamId
        }
        if let role = user.role {
            data["role"] = role.rawValue
        }
        if let createdAt = user.createdAt {
            data["createdAt"] = Timestamp(date: createdAt)
        }
        
        try await db.collection(usersCollection).document(user.id).setData(data, merge: true)
    }
    
    func getUserTeamId(_ userId: String) async throws -> String? {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        return document.data()?["teamId"] as? String
    }
    
    func setUserTeam(userId: String, teamId: String, role: UserRole) async throws {
        try await db.collection(usersCollection).document(userId).setData([
            "teamId": teamId,
            "role": role.rawValue,
            "updatedAt": Timestamp()
        ], merge: true)
    }
    
    func removeUserTeam(userId: String) async throws {
        try await db.collection(usersCollection).document(userId).updateData([
            "teamId": FieldValue.delete(),
            "role": FieldValue.delete(),
            "updatedAt": Timestamp()
        ])
    }
}


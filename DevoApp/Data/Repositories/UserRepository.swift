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
        
        // Cargar equipos (nuevo formato) o migrar desde teamId (formato antiguo)
        var teams: [UserTeam] = []
        if let teamsData = data["teams"] as? [[String: Any]] {
            // Nuevo formato: array de equipos
            for teamData in teamsData {
                if let teamId = teamData["teamId"] as? String,
                   let roleString = teamData["role"] as? String,
                   let role = UserRole(rawValue: roleString),
                   let joinedAtTimestamp = teamData["joinedAt"] as? Timestamp {
                    teams.append(UserTeam(
                        teamId: teamId,
                        role: role,
                        joinedAt: joinedAtTimestamp.dateValue()
                    ))
                }
            }
        } else if let teamId = data["teamId"] as? String,
                  let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) {
            // Formato antiguo: migrar a nuevo formato
            teams = [UserTeam(teamId: teamId, role: role, joinedAt: Date())]
        }
        
        return UserEntity(
            id: userId,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String,
            firstName: data["firstName"] as? String,
            lastName: data["lastName"] as? String,
            teamId: data["teamId"] as? String, // Mantener para compatibilidad
            role: (data["role"] as? String).flatMap { UserRole(rawValue: $0) }, // Mantener para compatibilidad
            teams: teams,
            selectedTeamId: data["selectedTeamId"] as? String,
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
        
        // Mantener teamId y role para compatibilidad (usar el primer equipo si existe)
        if let firstTeam = user.teams.first {
            data["teamId"] = firstTeam.teamId
            data["role"] = firstTeam.role.rawValue
        } else if let teamId = user.teamId {
            data["teamId"] = teamId
            if let role = user.role {
                data["role"] = role.rawValue
            }
        }
        
        // Guardar array de equipos
        if !user.teams.isEmpty {
            data["teams"] = user.teams.map { team in
                [
                    "teamId": team.teamId,
                    "role": team.role.rawValue,
                    "joinedAt": Timestamp(date: team.joinedAt)
                ]
            }
        }
        
        // Guardar equipo seleccionado
        if let selectedTeamId = user.selectedTeamId {
            data["selectedTeamId"] = selectedTeamId
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
            "teams": FieldValue.delete(),
            "selectedTeamId": FieldValue.delete(),
            "updatedAt": Timestamp()
        ])
    }
    
    // MARK: - Nuevos métodos para múltiples equipos
    
    func getUserTeams(_ userId: String) async -> [UserTeam] {
        guard let document = try? await db.collection(usersCollection).document(userId).getDocument(),
              let data = document.data() else {
            return []
        }
        
        var teams: [UserTeam] = []
        if let teamsData = data["teams"] as? [[String: Any]] {
            for teamData in teamsData {
                if let teamId = teamData["teamId"] as? String,
                   let roleString = teamData["role"] as? String,
                   let role = UserRole(rawValue: roleString),
                   let joinedAtTimestamp = teamData["joinedAt"] as? Timestamp {
                    teams.append(UserTeam(
                        teamId: teamId,
                        role: role,
                        joinedAt: joinedAtTimestamp.dateValue()
                    ))
                }
            }
        } else if let teamId = data["teamId"] as? String,
                  let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) {
            // Migrar formato antiguo
            teams = [UserTeam(teamId: teamId, role: role, joinedAt: Date())]
        }
        
        return teams
    }
    
    func addUserTeam(userId: String, teamId: String, role: UserRole) async throws {
        let document = db.collection(usersCollection).document(userId)
        let doc = try await document.getDocument()
        
        var teams: [UserTeam] = []
        if let data = doc.data(), let teamsData = data["teams"] as? [[String: Any]] {
            // Cargar equipos existentes
            for teamData in teamsData {
                if let existingTeamId = teamData["teamId"] as? String,
                   let roleString = teamData["role"] as? String,
                   let existingRole = UserRole(rawValue: roleString),
                   let joinedAtTimestamp = teamData["joinedAt"] as? Timestamp {
                    teams.append(UserTeam(
                        teamId: existingTeamId,
                        role: existingRole,
                        joinedAt: joinedAtTimestamp.dateValue()
                    ))
                }
            }
        } else if let data = doc.data(),
                  let existingTeamId = data["teamId"] as? String,
                  let roleString = data["role"] as? String,
                  let existingRole = UserRole(rawValue: roleString) {
            // Migrar formato antiguo
            teams = [UserTeam(teamId: existingTeamId, role: existingRole, joinedAt: Date())]
        }
        
        // Verificar que no esté duplicado
        guard !teams.contains(where: { $0.teamId == teamId }) else {
            throw NSError(domain: "UserRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "El usuario ya pertenece a este equipo"])
        }
        
        // Agregar nuevo equipo
        teams.append(UserTeam(teamId: teamId, role: role, joinedAt: Date()))
        
        // Guardar
        var updateData: [String: Any] = [
            "teams": teams.map { team in
                [
                    "teamId": team.teamId,
                    "role": team.role.rawValue,
                    "joinedAt": Timestamp(date: team.joinedAt)
                ]
            },
            "updatedAt": Timestamp()
        ]
        
        // Si es el primer equipo, establecerlo como seleccionado y mantener compatibilidad
        if teams.count == 1 {
            updateData["selectedTeamId"] = teamId
            updateData["teamId"] = teamId // Compatibilidad
            updateData["role"] = role.rawValue // Compatibilidad
        }
        
        try await document.setData(updateData, merge: true)
    }
    
    func removeUserTeam(userId: String, teamId: String) async throws {
        let document = db.collection(usersCollection).document(userId)
        let doc = try await document.getDocument()
        guard let data = doc.data() else {
            return
        }
        
        var teams: [UserTeam] = []
        if let teamsData = data["teams"] as? [[String: Any]] {
            for teamData in teamsData {
                if let existingTeamId = teamData["teamId"] as? String,
                   let roleString = teamData["role"] as? String,
                   let role = UserRole(rawValue: roleString),
                   let joinedAtTimestamp = teamData["joinedAt"] as? Timestamp {
                    teams.append(UserTeam(
                        teamId: existingTeamId,
                        role: role,
                        joinedAt: joinedAtTimestamp.dateValue()
                    ))
                }
            }
        }
        
        // Remover el equipo
        teams.removeAll { $0.teamId == teamId }
        
        var updateData: [String: Any] = [
            "updatedAt": Timestamp()
        ]
        
        if teams.isEmpty {
            // Si no quedan equipos, limpiar todo
            updateData["teams"] = FieldValue.delete()
            updateData["selectedTeamId"] = FieldValue.delete()
            updateData["teamId"] = FieldValue.delete()
            updateData["role"] = FieldValue.delete()
        } else {
            // Actualizar array de equipos
            updateData["teams"] = teams.map { team in
                [
                    "teamId": team.teamId,
                    "role": team.role.rawValue,
                    "joinedAt": Timestamp(date: team.joinedAt)
                ]
            }
            
            // Si el equipo eliminado era el seleccionado, seleccionar el primero
            let selectedTeamId = data["selectedTeamId"] as? String
            if selectedTeamId == teamId {
                updateData["selectedTeamId"] = teams.first?.teamId
            }
            
            // Mantener compatibilidad con el primer equipo
            if let firstTeam = teams.first {
                updateData["teamId"] = firstTeam.teamId
                updateData["role"] = firstTeam.role.rawValue
            }
        }
        
        try await document.setData(updateData, merge: true)
    }
    
    func setSelectedTeam(userId: String, teamId: String) async throws {
        // Verificar que el usuario pertenezca a este equipo
        let teams = await getUserTeams(userId)
        guard teams.contains(where: { $0.teamId == teamId }) else {
            throw NSError(domain: "UserRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "El usuario no pertenece a este equipo"])
        }
        
        try await db.collection(usersCollection).document(userId).setData([
            "selectedTeamId": teamId,
            "updatedAt": Timestamp()
        ], merge: true)
    }
    
    func getSelectedTeamId(_ userId: String) async -> String? {
        guard let document = try? await db.collection(usersCollection).document(userId).getDocument(),
              let data = document.data() else {
            return nil
        }
        
        // Intentar obtener selectedTeamId
        if let selectedTeamId = data["selectedTeamId"] as? String {
            return selectedTeamId
        }
        
        // Fallback: usar el primer equipo o teamId antiguo
        if let teamsData = data["teams"] as? [[String: Any]],
           let firstTeam = teamsData.first,
           let teamId = firstTeam["teamId"] as? String {
            return teamId
        }
        
        return data["teamId"] as? String
    }
}


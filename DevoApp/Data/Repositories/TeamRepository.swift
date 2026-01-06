import Foundation
import FirebaseFirestore

// MARK: - Team Repository Implementation
// Implementación concreta del protocolo, usando Firestore

final class TeamRepository: TeamRepositoryProtocol {
    private let db: Firestore
    private let teamsCollection = "teams"
    
    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }
    
    func createTeam(name: String, leaderId: String, leaderName: String) async throws -> TeamEntity {
        let code = try await generateUniqueTeamCode()
        let now = Timestamp()
        
        let teamData = TeamDataModel(
            name: name,
            code: code,
            leaderId: leaderId,
            leaderName: leaderName,
            memberIds: [],
            createdAt: now,
            updatedAt: now
        )
        
        let docRef = try await db.collection(teamsCollection).addDocument(from: teamData)
        
        guard !docRef.documentID.isEmpty else {
            throw NSError(domain: "TeamRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al crear el equipo: ID vacío"])
        }
        
        var updatedTeamData = teamData
        updatedTeamData.id = docRef.documentID
        
        return updatedTeamData.toDomain()
    }
    
    func findTeamByCode(_ code: String) async throws -> TeamEntity? {
        let querySnapshot = try await db.collection(teamsCollection)
            .whereField("code", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
        
        guard let document = querySnapshot.documents.first else {
            return nil
        }
        
        let teamData = try document.data(as: TeamDataModel.self)
        return teamData.toDomain()
    }
    
    func getTeamById(_ teamId: String) async throws -> TeamEntity? {
        let document = try await db.collection(teamsCollection).document(teamId).getDocument()
        
        guard document.exists else {
            return nil
        }
        
        let teamData = try document.data(as: TeamDataModel.self)
        return teamData.toDomain()
    }
    
    func updateTeam(_ team: TeamEntity) async throws {
        guard let teamId = team.id else {
            throw NSError(domain: "TeamRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Team ID is required"])
        }
        
        let teamData = TeamDataModel.fromDomain(team)
        try await db.collection(teamsCollection).document(teamId).setData(from: teamData)
    }
    
    func addMemberToTeam(teamId: String, memberId: String) async throws {
        let teamRef = db.collection(teamsCollection).document(teamId)
        
        try await teamRef.updateData([
            "memberIds": FieldValue.arrayUnion([memberId]),
            "updatedAt": Timestamp()
        ])
    }
    
    func removeMemberFromTeam(teamId: String, memberId: String) async throws {
        let teamRef = db.collection(teamsCollection).document(teamId)
        
        try await teamRef.updateData([
            "memberIds": FieldValue.arrayRemove([memberId]),
            "updatedAt": Timestamp()
        ])
    }
    
    func generateUniqueTeamCode() async throws -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let codeLength = 6
        let maxAttempts = 10
        
        for _ in 0..<maxAttempts {
            let code = String((0..<codeLength).map { _ in
                characters.randomElement()!
            })
            
            let exists = try await checkCodeExists(code)
            if !exists {
                return code
            }
        }
        
        // Fallback: usar timestamp
        let timestamp = String(Int(Date().timeIntervalSince1970))
        return String(timestamp.suffix(codeLength)).uppercased()
    }
    
    func checkCodeExists(_ code: String) async throws -> Bool {
        let querySnapshot = try await db.collection(teamsCollection)
            .whereField("code", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
        
        return !querySnapshot.documents.isEmpty
    }
}


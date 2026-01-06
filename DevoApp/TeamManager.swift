import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TeamManager: ObservableObject {
    @Published var currentTeam: Team?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private let teamsCollection = "teams"
    
    // MARK: - Create Team
    
    func createTeam(name: String, leaderId: String, leaderName: String) async -> Team? {
        // Validar nombre del equipo
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString("team_name_required", comment: "")
            return nil
        }
        
        // Validar que el nombre no sea demasiado largo
        guard trimmedName.count <= 50 else {
            errorMessage = "El nombre del equipo no puede tener más de 50 caracteres"
            return nil
        }
        
        // Validar usuario autenticado
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return nil
        }
        
        // Verificar que el usuario no tenga ya un equipo
        do {
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            if let existingTeamId = userDoc.data()?["teamId"] as? String, !existingTeamId.isEmpty {
                errorMessage = "Ya perteneces a un equipo. Debes salir del equipo actual antes de crear uno nuevo."
                return nil
            }
        } catch {
            // Si hay error al verificar, continuamos (puede ser que el documento no exista)
            print("Warning: Could not check existing team: \(error.localizedDescription)")
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Generar código único
            let code = try await generateUniqueTeamCode()
            
            // Crear el equipo con timestamp actual
            let now = Timestamp()
            let team = Team(
                name: trimmedName,
                code: code,
                leaderId: leaderId,
                leaderName: leaderName,
                memberIds: [],
                createdAt: now,
                updatedAt: now
            )
            
            // Guardar en Firestore
            let docRef = try await db.collection(teamsCollection).addDocument(from: team)
            
            // Verificar que el documento se creó correctamente
            guard !docRef.documentID.isEmpty else {
                throw NSError(domain: "TeamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al crear el equipo: ID vacío"])
            }
            
            // Actualizar el equipo local con el ID generado
            var updatedTeam = team
            updatedTeam.id = docRef.documentID
            
            // Guardar referencia del equipo en el perfil del usuario
            try await db.collection("users").document(user.uid).setData([
                "teamId": docRef.documentID,
                "role": "leader",
                "updatedAt": Timestamp()
            ], merge: true)
            
            // Verificar que se guardó correctamente
            let verificationDoc = try await db.collection("users").document(user.uid).getDocument()
            guard let savedTeamId = verificationDoc.data()?["teamId"] as? String,
                  savedTeamId == docRef.documentID else {
                throw NSError(domain: "TeamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al guardar la referencia del equipo en el perfil del usuario"])
            }
            
            isLoading = false
            currentTeam = updatedTeam
            
            print("✅ Equipo creado exitosamente: \(updatedTeam.name) con código: \(updatedTeam.code)")
            
            return updatedTeam
            
        } catch {
            isLoading = false
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc.isEmpty ? "Error desconocido al crear el equipo" : errorDesc
            print("❌ Error al crear equipo: \(errorDesc)")
            return nil
        }
    }
    
    // MARK: - Join Team by Code
    
    func joinTeam(code: String) async -> Bool {
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = NSLocalizedString("team_code_required", comment: "")
            return false
        }
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return false
        }
        
        let normalizedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Buscar equipo por código
            let querySnapshot = try await db.collection(teamsCollection)
                .whereField("code", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = querySnapshot.documents.first else {
                errorMessage = NSLocalizedString("team_not_found", comment: "")
                isLoading = false
                return false
            }
            
            // Verificar que el usuario no sea el líder
            let team = try document.data(as: Team.self)
            
            if team.leaderId == user.uid {
                errorMessage = NSLocalizedString("already_team_leader", comment: "")
                isLoading = false
                return false
            }
            
            // Verificar que el usuario no esté ya en el equipo
            if team.memberIds.contains(user.uid) {
                errorMessage = NSLocalizedString("already_team_member", comment: "")
                isLoading = false
                return false
            }
            
            // Agregar usuario al equipo
            var updatedMemberIds = team.memberIds
            updatedMemberIds.append(user.uid)
            
            try await document.reference.updateData([
                "memberIds": updatedMemberIds,
                "updatedAt": Timestamp()
            ])
            
            // Guardar referencia del equipo en el perfil del usuario
            try await db.collection("users").document(user.uid).setData([
                "teamId": document.documentID,
                "role": "member",
                "updatedAt": Timestamp()
            ], merge: true)
            
            // Actualizar el equipo local
            var updatedTeam = team
            updatedTeam.memberIds = updatedMemberIds
            updatedTeam.updatedAt = Timestamp()
            currentTeam = updatedTeam
            
            isLoading = false
            return true
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Get Current User's Team
    
    func loadCurrentUserTeam() async {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        
        do {
            // Obtener información del usuario
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            
            guard let teamId = userDoc.data()?["teamId"] as? String else {
                isLoading = false
                return
            }
            
            // Obtener el equipo
            let teamDoc = try await db.collection(teamsCollection).document(teamId).getDocument()
            
            if teamDoc.exists {
                currentTeam = try teamDoc.data(as: Team.self)
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Remove Member
    
    func removeMember(memberId: String, fromTeam team: Team) async {
        guard let teamId = team.id else {
            errorMessage = NSLocalizedString("team_id_missing", comment: "")
            return
        }
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return
        }
        
        // Verificar que el usuario es el líder
        guard team.leaderId == user.uid else {
            errorMessage = NSLocalizedString("only_leader_can_remove", comment: "")
            return
        }
        
        // Verificar que el miembro existe en el equipo
        guard team.memberIds.contains(memberId) else {
            errorMessage = NSLocalizedString("member_not_in_team", comment: "")
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Remover miembro del equipo
            var updatedMemberIds = team.memberIds
            updatedMemberIds.removeAll { $0 == memberId }
            
            try await db.collection(teamsCollection).document(teamId).updateData([
                "memberIds": updatedMemberIds,
                "updatedAt": Timestamp()
            ])
            
            // Remover referencia del equipo en el perfil del usuario
            try await db.collection("users").document(memberId).updateData([
                "teamId": FieldValue.delete(),
                "role": FieldValue.delete()
            ])
            
            // Actualizar el equipo local
            var updatedTeam = team
            updatedTeam.memberIds = updatedMemberIds
            updatedTeam.updatedAt = Timestamp()
            currentTeam = updatedTeam
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Refresh Team
    
    func refreshTeam() async {
        await loadCurrentUserTeam()
    }
    
    // MARK: - Generate Unique Team Code
    
    private func generateUniqueTeamCode() async throws -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Sin I, O, 0, 1 para evitar confusión
        let codeLength = 6
        
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            // Generar código aleatorio
            let code = String((0..<codeLength).map { _ in
                characters.randomElement()!
            })
            
            // Verificar si el código ya existe
            let querySnapshot = try await db.collection(teamsCollection)
                .whereField("code", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            
            if querySnapshot.documents.isEmpty {
                return code
            }
            
            attempts += 1
        }
        
        // Si después de varios intentos no encontramos uno único, usar timestamp
        let timestamp = String(Int(Date().timeIntervalSince1970))
        return String(timestamp.suffix(codeLength)).uppercased()
    }
}


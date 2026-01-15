import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class TeamManager: ObservableObject {
    @Published var currentTeam: Team? // Equipo seleccionado actualmente
    @Published var allTeams: [Team] = [] // Todos los equipos del usuario
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private let teamsCollection = "teams"
    private var userListener: ListenerRegistration?
    private var teamListener: ListenerRegistration?
    private var selectedTeamId: String?
    
    deinit {
        // Limpiar listeners sin necesidad de main actor
        userListener?.remove()
        teamListener?.remove()
    }
    
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
        
        // Validación de seguridad: verificar que el leaderId coincida con el usuario autenticado
        guard leaderId == user.uid else {
            errorMessage = "Error de seguridad: El leaderId no coincide con el usuario autenticado"
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
        
        print("🔄 [TeamManager] isLoading = true, iniciando creación...")
        
        do {
            // Generar código único
            print("🔑 [TeamManager] Generando código único...")
            let code = try await generateUniqueTeamCode()
            print("🔑 [TeamManager] Código generado: \(code)")
            
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
            
            // Guardar en Firestore usando setData para evitar problemas con @DocumentID
            print("💾 [TeamManager] Guardando equipo en Firestore...")
            print("🔐 [TeamManager] Usuario autenticado: \(user.uid)")
            print("🔐 [TeamManager] Email: \(user.email ?? "sin email")")
            
            let docRef = db.collection(teamsCollection).document()
            let teamData: [String: Any] = [
                "name": team.name,
                "code": team.code,
                "leaderId": team.leaderId,
                "leaderName": team.leaderName,
                "memberIds": team.memberIds,
                "createdAt": team.createdAt,
                "updatedAt": team.updatedAt
            ]
            print("📝 [TeamManager] Datos a guardar: \(teamData)")
            try await docRef.setData(teamData)
            print("💾 [TeamManager] Documento creado con ID: \(docRef.documentID)")
            
            // Verificar que el documento se creó correctamente
            guard !docRef.documentID.isEmpty else {
                throw NSError(domain: "TeamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al crear el equipo: ID vacío"])
            }
            
            // Actualizar el equipo local con el ID generado
            var updatedTeam = team
            updatedTeam.id = docRef.documentID
            
            // Guardar referencia del equipo en el perfil del usuario (nuevo formato con array)
            print("👤 [TeamManager] Actualizando perfil del usuario con teamId: \(docRef.documentID)")
            
            // Obtener equipos existentes
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            var teams: [[String: Any]] = []
            
            if let data = userDoc.data(), let teamsData = data["teams"] as? [[String: Any]] {
                teams = teamsData
            } else if let existingTeamId = userDoc.data()?["teamId"] as? String,
                      let roleString = userDoc.data()?["role"] as? String {
                // Migrar formato antiguo
                teams = [[
                    "teamId": existingTeamId,
                    "role": roleString,
                    "joinedAt": Timestamp()
                ]]
            }
            
            // Agregar nuevo equipo
            teams.append([
                "teamId": docRef.documentID,
                "role": "leader",
                "joinedAt": Timestamp()
            ])
            
            // Guardar con nuevo formato
            try await db.collection("users").document(user.uid).setData([
                "teams": teams,
                "selectedTeamId": docRef.documentID, // Establecer como seleccionado
                "teamId": docRef.documentID, // Compatibilidad
                "role": "leader", // Compatibilidad
                "updatedAt": Timestamp()
            ], merge: true)
            print("👤 [TeamManager] Perfil del usuario actualizado")
            
            // Verificar que se guardó correctamente
            print("🔍 [TeamManager] Verificando que se guardó correctamente...")
            let verificationDoc = try await db.collection("users").document(user.uid).getDocument()
            guard let savedData = verificationDoc.data(),
                  let savedTeams = savedData["teams"] as? [[String: Any]],
                  savedTeams.contains(where: { ($0["teamId"] as? String) == docRef.documentID }) else {
                throw NSError(domain: "TeamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al guardar la referencia del equipo en el perfil del usuario"])
            }
            print("✅ [TeamManager] Verificación exitosa, equipo guardado en array")
            
            isLoading = false
            currentTeam = updatedTeam
            selectedTeamId = docRef.documentID
            
            // Actualizar lista de equipos
            allTeams.append(updatedTeam)
            
            // Iniciar listeners después de crear el equipo
            startListening(userId: user.uid, teamId: docRef.documentID)
            
            print("✅ [TeamManager] Equipo creado exitosamente: \(updatedTeam.name) con código: \(updatedTeam.code)")
            print("🔄 [TeamManager] isLoading = false, currentTeam actualizado")
            
            return updatedTeam
            
        } catch {
            isLoading = false
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc.isEmpty ? "Error desconocido al crear el equipo" : errorDesc
            print("❌ [TeamManager] Error al crear equipo:")
            print("   - Error: \(errorDesc)")
            print("   - Domain: \((error as NSError).domain)")
            print("   - Code: \((error as NSError).code)")
            print("🔄 [TeamManager] isLoading = false después del error")
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
            
            // Guardar referencia del equipo en el perfil del usuario (nuevo formato con array)
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            var teams: [[String: Any]] = []
            
            if let data = userDoc.data(), let teamsData = data["teams"] as? [[String: Any]] {
                teams = teamsData
            } else if let existingTeamId = userDoc.data()?["teamId"] as? String,
                      let roleString = userDoc.data()?["role"] as? String {
                // Migrar formato antiguo
                teams = [[
                    "teamId": existingTeamId,
                    "role": roleString,
                    "joinedAt": Timestamp()
                ]]
            }
            
            // Agregar nuevo equipo
            teams.append([
                "teamId": document.documentID,
                "role": "member",
                "joinedAt": Timestamp()
            ])
            
            // Guardar con nuevo formato
            try await db.collection("users").document(user.uid).setData([
                "teams": teams,
                "selectedTeamId": document.documentID, // Establecer como seleccionado
                "teamId": document.documentID, // Compatibilidad
                "role": "member", // Compatibilidad
                "updatedAt": Timestamp()
            ], merge: true)
            
            // Actualizar el equipo local
            var updatedTeam = team
            updatedTeam.memberIds = updatedMemberIds
            updatedTeam.updatedAt = Timestamp()
            updatedTeam.id = document.documentID
            currentTeam = updatedTeam
            selectedTeamId = document.documentID
            
            // Actualizar lista de equipos
            if !allTeams.contains(where: { $0.id == document.documentID }) {
                allTeams.append(updatedTeam)
            } else {
                // Actualizar equipo existente en la lista
                if let index = allTeams.firstIndex(where: { $0.id == document.documentID }) {
                    allTeams[index] = updatedTeam
                }
            }
            
            // Iniciar listeners después de unirse al equipo
            startListening(userId: user.uid, teamId: document.documentID)
            
            isLoading = false
            return true
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Load All User Teams
    
    func loadAllUserTeams() async {
        guard let user = Auth.auth().currentUser else {
            allTeams = []
            currentTeam = nil
            stopListening()
            return
        }
        
        isLoading = true
        
        do {
            // Obtener información del usuario
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            guard let data = userDoc.data() else {
                allTeams = []
                currentTeam = nil
                isLoading = false
                stopListening()
                return
            }
            
            // Obtener array de equipos (nuevo formato) o migrar desde teamId (formato antiguo)
            var teamIds: [String] = []
            
            if let teamsData = data["teams"] as? [[String: Any]] {
                // Nuevo formato: array de equipos
                for teamData in teamsData {
                    if let teamId = teamData["teamId"] as? String {
                        teamIds.append(teamId)
                    }
                }
            } else if let teamId = data["teamId"] as? String {
                // Formato antiguo: migrar
                teamIds = [teamId]
            }
            
            // Obtener el equipo seleccionado
            let selectedId = data["selectedTeamId"] as? String ?? teamIds.first
            
            // Cargar todos los equipos
            var loadedTeams: [Team] = []
            for teamId in teamIds {
                let teamDoc = try await db.collection(teamsCollection).document(teamId).getDocument()
                if teamDoc.exists {
                    if let team = try? teamDoc.data(as: Team.self) {
                        loadedTeams.append(team)
                    }
                }
            }
            
            allTeams = loadedTeams
            selectedTeamId = selectedId
            
            // Establecer el equipo actual
            if let selectedId = selectedId,
               let team = loadedTeams.first(where: { $0.id == selectedId }) {
                print("✅ [TeamManager] Estableciendo equipo seleccionado: \(team.name) (ID: \(selectedId))")
                currentTeam = team
                selectedTeamId = selectedId
                startListening(userId: user.uid, teamId: selectedId)
            } else if let firstTeam = loadedTeams.first {
                // Si no hay seleccionado, usar el primero
                print("✅ [TeamManager] No hay equipo seleccionado, usando el primero: \(firstTeam.name)")
                currentTeam = firstTeam
                selectedTeamId = firstTeam.id
                // Actualizar selectedTeamId en Firestore
                if let teamId = firstTeam.id {
                    try? await db.collection("users").document(user.uid).setData([
                        "selectedTeamId": teamId,
                        "updatedAt": Timestamp()
                    ], merge: true)
                }
                startListening(userId: user.uid, teamId: firstTeam.id ?? "")
            } else {
                print("⚠️ [TeamManager] No se encontraron equipos")
                currentTeam = nil
                stopListening()
            }
            
            isLoading = false
            print("🔄 [TeamManager] loadAllUserTeams completado. currentTeam: \(currentTeam?.name ?? "nil"), total equipos: \(allTeams.count)")
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            allTeams = []
            currentTeam = nil
        }
    }
    
    // MARK: - Load Current User's Team (compatibilidad hacia atrás)
    
    func loadCurrentUserTeam() async {
        await loadAllUserTeams()
    }
    
    // MARK: - Switch Team
    
    func switchTeam(teamId: String) async {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        // Verificar que el equipo existe en la lista de equipos del usuario
        guard allTeams.contains(where: { $0.id == teamId }) else {
            errorMessage = "No perteneces a este equipo"
            return
        }
        
        isLoading = true
        
        do {
            // Actualizar el equipo seleccionado en Firestore
            try await db.collection("users").document(user.uid).setData([
                "selectedTeamId": teamId,
                "updatedAt": Timestamp()
            ], merge: true)
            
            // Actualizar el equipo actual
            if let team = allTeams.first(where: { $0.id == teamId }) {
                currentTeam = team
                selectedTeamId = teamId
                startListening(userId: user.uid, teamId: teamId)
                
                // Notificar que se cambió de equipo
                NotificationCenter.default.post(name: NSNotification.Name("TeamSwitched"), object: nil, userInfo: ["teamId": teamId])
                print("📢 [TeamManager] Equipo cambiado a: \(team.name) (ID: \(teamId))")
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Real-time Listeners
    
    func startListening(userId: String, teamId: String) {
        // Detener listeners anteriores si existen
        stopListening()
        
        print("👂 [TeamManager] Iniciando listeners para usuario: \(userId), equipo: \(teamId)")
        
        // Listener para cambios en el documento del usuario
        userListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ [TeamManager] Error en listener de usuario: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("⚠️ [TeamManager] Documento de usuario no existe")
                        self.currentTeam = nil
                        self.stopListening()
                        return
                    }
                    
                    let data = document.data()
                    
                    // Verificar usando el nuevo formato (teams array)
                    var userHasTeam = false
                    if let teamsData = data?["teams"] as? [[String: Any]] {
                        userHasTeam = teamsData.contains { ($0["teamId"] as? String) == teamId }
                    } else if let userTeamId = data?["teamId"] as? String {
                        // Formato antiguo (compatibilidad)
                        userHasTeam = userTeamId == teamId
                    }
                    
                    // Si el usuario ya no tiene este equipo, recargar equipos
                    if !userHasTeam {
                        print("🔄 [TeamManager] Usuario ya no pertenece a este equipo, recargando equipos...")
                        self.stopListening()
                        // Recargar equipos para actualizar currentTeam automáticamente
                        await self.loadAllUserTeams()
                        NotificationCenter.default.post(name: NSNotification.Name("TeamDeleted"), object: nil)
                    } else {
                        // Si el usuario aún tiene el equipo, verificar si hay cambios en selectedTeamId
                        let selectedId = data?["selectedTeamId"] as? String
                        if selectedId != teamId && selectedId != nil {
                            // El usuario cambió de equipo, recargar para obtener el nuevo equipo
                            await self.loadAllUserTeams()
                        }
                        // Si selectedId es nil pero el usuario tiene el equipo, no hacer nada
                        // (puede ser que se esté creando el equipo)
                    }
                }
            }
        
        // Listener para cambios en el documento del equipo
        teamListener = db.collection(teamsCollection).document(teamId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ [TeamManager] Error en listener de equipo: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = documentSnapshot, document.exists else {
                        print("🔄 [TeamManager] Listener detectó que el equipo fue eliminado, recargando equipos...")
                        self.stopListening()
                        // Recargar equipos para actualizar currentTeam automáticamente
                        Task { @MainActor in
                            await self.loadAllUserTeams()
                            NotificationCenter.default.post(name: NSNotification.Name("TeamDeleted"), object: nil)
                        }
                        return
                    }
                    
                    // Actualizar el equipo si existe
                    do {
                        let team = try document.data(as: Team.self)
                        self.currentTeam = team
                        print("🔄 [TeamManager] Equipo actualizado desde listener")
                    } catch {
                        print("❌ [TeamManager] Error al parsear equipo: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    func stopListening() {
        userListener?.remove()
        teamListener?.remove()
        userListener = nil
        teamListener = nil
        print("🛑 [TeamManager] Listeners detenidos")
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
    
    // MARK: - Leave Team
    
    func leaveTeam() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return false
        }
        
        guard let team = currentTeam, let teamId = team.id else {
            errorMessage = NSLocalizedString("team_not_found", comment: "")
            return false
        }
        
        // Verificar que el usuario no es el líder
        guard team.leaderId != user.uid else {
            errorMessage = NSLocalizedString("leader_cannot_leave", comment: "El líder no puede salir del equipo. Debe eliminarlo.")
            return false
        }
        
        // Verificar que el usuario es miembro del equipo
        guard team.memberIds.contains(user.uid) else {
            errorMessage = NSLocalizedString("not_team_member", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        print("🚪 [TeamManager] Usuario \(user.uid) saliendo del equipo \(team.name)...")
        
        do {
            // Remover usuario de la lista de miembros del equipo
            var updatedMemberIds = team.memberIds
            updatedMemberIds.removeAll { $0 == user.uid }
            
            try await db.collection(teamsCollection).document(teamId).updateData([
                "memberIds": updatedMemberIds,
                "updatedAt": Timestamp()
            ])
            
            print("✅ [TeamManager] Usuario removido del equipo en Firestore")
            
            // Remover referencia del equipo en el perfil del usuario
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            
            if let data = userDoc.data(), var teams = data["teams"] as? [[String: Any]] {
                // Remover el equipo del array de teams
                teams.removeAll { ($0["teamId"] as? String) == teamId }
                
                // Si no quedan equipos, limpiar selectedTeamId
                let updatedData: [String: Any] = [
                    "teams": teams,
                    "updatedAt": Timestamp()
                ]
                
                if teams.isEmpty {
                    // Si no hay más equipos, limpiar selectedTeamId
                    try await db.collection("users").document(user.uid).setData([
                        "teams": teams,
                        "selectedTeamId": FieldValue.delete(),
                        "teamId": FieldValue.delete(), // Compatibilidad
                        "role": FieldValue.delete(), // Compatibilidad
                        "updatedAt": Timestamp()
                    ], merge: true)
                } else {
                    // Si hay otros equipos, actualizar selectedTeamId al primero disponible
                    if let firstTeamId = teams.first?["teamId"] as? String {
                        try await db.collection("users").document(user.uid).setData([
                            "teams": teams,
                            "selectedTeamId": firstTeamId,
                            "teamId": firstTeamId, // Compatibilidad
                            "role": teams.first?["role"] as? String ?? "member", // Compatibilidad
                            "updatedAt": Timestamp()
                        ], merge: true)
                    } else {
                        try await db.collection("users").document(user.uid).setData(updatedData, merge: true)
                    }
                }
            } else {
                // Formato antiguo, limpiar campos
                try await db.collection("users").document(user.uid).updateData([
                    "teamId": FieldValue.delete(),
                    "role": FieldValue.delete(),
                    "updatedAt": Timestamp()
                ])
            }
            
            print("✅ [TeamManager] Referencia del equipo removida del perfil del usuario")
            
            // Detener listeners del equipo
            stopListening()
            
            // Recargar todos los equipos para actualizar currentTeam
            print("🔄 [TeamManager] Recargando equipos después de salir...")
            await loadAllUserTeams()
            
            isLoading = false
            
            print("✅ [TeamManager] Usuario salió del equipo exitosamente")
            print("   Equipos restantes: \(allTeams.count)")
            print("   Equipo actual: \(currentTeam?.name ?? "ninguno")")
            
            // Notificar que el usuario salió del equipo
            NotificationCenter.default.post(name: NSNotification.Name("TeamLeft"), object: nil)
            
            return true
            
        } catch {
            isLoading = false
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc.isEmpty ? "Error desconocido al salir del equipo" : errorDesc
            print("❌ [TeamManager] Error al salir del equipo:")
            print("   - Error: \(errorDesc)")
            return false
        }
    }
    
    // MARK: - Delete Team
    
    func deleteTeam() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = NSLocalizedString("user_not_authenticated", comment: "")
            return false
        }
        
        guard let team = currentTeam, let teamId = team.id else {
            errorMessage = NSLocalizedString("team_not_found", comment: "")
            return false
        }
        
        // Verificar que el usuario es el líder
        guard team.leaderId == user.uid else {
            errorMessage = NSLocalizedString("only_leader_can_delete", comment: "")
            return false
        }
        
        isLoading = true
        errorMessage = ""
        
        print("🗑️ [TeamManager] Iniciando eliminación del equipo: \(team.name) (ID: \(teamId))")
        
        do {
            // Obtener todos los miembros del equipo (incluyendo el líder)
            var allMemberIds = team.memberIds
            allMemberIds.append(team.leaderId)
            
            print("👥 [TeamManager] Eliminando referencias de \(allMemberIds.count) usuarios...")
            
            // Eliminar referencias del equipo en todos los usuarios
            let batch = db.batch()
            for memberId in allMemberIds {
                let userRef = db.collection("users").document(memberId)
                batch.updateData([
                    "teamId": FieldValue.delete(),
                    "role": FieldValue.delete()
                ], forDocument: userRef)
            }
            
            // Eliminar el equipo
            let teamRef = db.collection(teamsCollection).document(teamId)
            batch.deleteDocument(teamRef)
            
            print("💾 [TeamManager] Ejecutando batch delete...")
            try await batch.commit()
            print("✅ [TeamManager] Batch delete completado exitosamente")
            
            // Detener listeners del equipo eliminado
            stopListening()
            
            // Recargar todos los equipos para actualizar currentTeam automáticamente
            // Esto evitará mostrar la pantalla de "find your team" si hay otros equipos
            print("🔄 [TeamManager] Recargando equipos después de eliminar...")
            await loadAllUserTeams()
            
            isLoading = false
            
            print("✅ [TeamManager] Equipo eliminado exitosamente")
            print("   Equipos restantes: \(allTeams.count)")
            print("   Equipo actual: \(currentTeam?.name ?? "ninguno")")
            
            // Notificar que el equipo fue eliminado (después de recargar)
            NotificationCenter.default.post(name: NSNotification.Name("TeamDeleted"), object: nil)
            
            return true
            
        } catch {
            isLoading = false
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc.isEmpty ? "Error desconocido al eliminar el equipo" : errorDesc
            print("❌ [TeamManager] Error al eliminar equipo:")
            print("   - Error: \(errorDesc)")
            print("   - Domain: \((error as NSError).domain)")
            print("   - Code: \((error as NSError).code)")
            return false
        }
    }
    
    // MARK: - Refresh Team
    
    func refreshTeam() async {
        // Recargar el equipo del usuario actual
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


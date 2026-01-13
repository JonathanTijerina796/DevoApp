import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTeamView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var teamManager: TeamManager
    @State private var userRole: String = "member"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let team = teamManager.currentTeam {
                        // Header del equipo
                        TeamHeaderCard(team: team)
                        
                        // Si es líder, mostrar vista de administración
                        if isLeader {
                            LeaderDashboardView(team: team)
                        } else {
                            // Si es miembro, mostrar vista de miembro
                            MemberDashboardView(team: team)
                        }
                    } else {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("my_team", comment: ""))
        }
        .task {
            await loadUserRole()
        }
    }
    
    private var isLeader: Bool {
        guard let team = teamManager.currentTeam,
              let userId = authManager.user?.uid else {
            return false
        }
        return team.leaderId == userId
    }
    
    private func loadUserRole() async {
        guard let user = authManager.user else { return }
        
        do {
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .getDocument()
            
            userRole = userDoc.data()?["role"] as? String ?? "member"
        } catch {
            print("Error loading user role: \(error)")
        }
    }
}

// MARK: - Team Header Card

struct TeamHeaderCard: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentBrand)
            
            Text(team.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
            
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .foregroundStyle(Color.secondaryText)
                Text("\(NSLocalizedString("code", comment: "")): \(team.code)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Leader Dashboard View

struct LeaderDashboardView: View {
    @EnvironmentObject var teamManager: TeamManager
    let team: Team
    @State private var showShareCode = false
    @State private var showMembers = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showCreateDevotional = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Botón para compartir código
            Button {
                showShareCode = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                    Text(NSLocalizedString("share_team_code", comment: ""))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Color.primaryText)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentBrand.opacity(0.1))
                )
            }
            
            // Botón para ver miembros
            Button {
                showMembers = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                    Text("\(NSLocalizedString("view_members", comment: "")) (\(team.memberIds.count))")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Color.primaryText)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
            
            // Botón para crear devocional con tema
            Button {
                showCreateDevotional = true
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                    Text(NSLocalizedString("create_devotional", comment: ""))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Color.primaryText)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
            
            // Botón para eliminar equipo
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text(NSLocalizedString("delete_team", comment: ""))
                        .font(.headline)
                    Spacer()
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .foregroundStyle(Color.red)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .disabled(isDeleting || teamManager.isLoading)
        }
        .sheet(isPresented: $showShareCode) {
            ShareCodeView(teamCode: team.code, teamName: team.name)
        }
        .sheet(isPresented: $showMembers) {
            TeamMembersView(team: team)
                .environmentObject(teamManager)
        }
        .sheet(isPresented: $showCreateDevotional) {
            if let teamId = team.id {
                CreateDevotionalView(teamId: teamId, teamName: team.name)
            }
        }
        .alert(NSLocalizedString("delete_team", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("delete_team", comment: ""), role: .destructive) {
                Task {
                    await deleteTeam()
                }
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("delete_team_confirmation", comment: ""))
                Text(NSLocalizedString("delete_team_warning", comment: ""))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
    
    private func deleteTeam() async {
        isDeleting = true
        print("🗑️ [LeaderDashboard] Iniciando eliminación del equipo...")
        
        let success = await teamManager.deleteTeam()
        
        isDeleting = false
        
        if success {
            print("✅ [LeaderDashboard] Equipo eliminado exitosamente")
        } else {
            print("❌ [LeaderDashboard] Error al eliminar equipo: \(teamManager.errorMessage)")
        }
    }
}

// MARK: - Member Dashboard View

struct MemberDashboardView: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("welcome_to_team", comment: ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            
            Text("\(NSLocalizedString("you_are_member_of", comment: "")) \(team.name)")
                .font(.system(size: 16))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Share Code View

struct ShareCodeView: View {
    let teamCode: String
    let teamName: String
    @Environment(\.dismiss) var dismiss
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentBrand)
                    
                    Text(NSLocalizedString("team_code", comment: ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                    
                    Text(teamName)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.top, 40)
                
                // Código destacado
                VStack(spacing: 12) {
                    Text(NSLocalizedString("code", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                    
                    Text(teamCode)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentBrand)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentBrand.opacity(0.1))
                        )
                }
                
                // Botón para copiar
                Button {
                    UIPasteboard.general.string = teamCode
                    showCopiedAlert = true
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text(NSLocalizedString("copy_code", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentBrand)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                
                // Botón para compartir
                Button {
                    shareCode()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(NSLocalizedString("share_code", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(Color.accentBrand)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentBrand, lineWidth: 2)
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("share_code_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .alert(NSLocalizedString("code_copied", comment: ""), isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(NSLocalizedString("code_copied_message", comment: ""))
            }
        }
    }
    
    private func shareCode() {
        let text = "\(NSLocalizedString("join_my_team", comment: "")) \(teamName). \(NSLocalizedString("team_code", comment: "")): \(teamCode)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Team Members View

struct TeamMembersView: View {
    @EnvironmentObject var teamManager: TeamManager
    let team: Team
    @Environment(\.dismiss) var dismiss
    @State private var members: [TeamMember] = []
    @State private var isLoading = true
    @State private var showRemoveAlert = false
    @State private var memberToRemove: TeamMember?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        // Líder
                        MemberRow(
                            name: team.leaderName,
                            role: NSLocalizedString("leader", comment: ""),
                            isLeader: true
                        )
                        
                        // Miembros
                        ForEach(members) { member in
                            MemberRow(
                                name: member.name,
                                role: NSLocalizedString("member", comment: ""),
                                isLeader: false,
                                onRemove: {
                                    memberToRemove = member
                                    showRemoveAlert = true
                                }
                            )
                        }
                        
                        if members.isEmpty {
                            Text(NSLocalizedString("no_members_yet", comment: ""))
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondaryText)
                                .padding()
                        }
                    }
                }
                .padding()
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("team_members", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .task {
                await loadMembers()
            }
            .alert(NSLocalizedString("remove_member", comment: ""), isPresented: $showRemoveAlert) {
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
                Button(NSLocalizedString("remove", comment: ""), role: .destructive) {
                    if let member = memberToRemove {
                        Task {
                            await removeMember(member)
                        }
                    }
                }
            } message: {
                if let member = memberToRemove {
                    Text("\(NSLocalizedString("remove_member_confirmation", comment: "")) \(member.name)?")
                }
            }
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        
        do {
            var loadedMembers: [TeamMember] = []
            
            for memberId in team.memberIds {
                let userDoc = try await Firestore.firestore()
                    .collection("users")
                    .document(memberId)
                    .getDocument()
                
                if let data = userDoc.data(),
                   let email = data["email"] as? String {
                    let displayName = data["displayName"] as? String ?? email
                    loadedMembers.append(TeamMember(id: memberId, name: displayName, email: email))
                } else {
                    // Si no hay datos del usuario, usar el UID como nombre
                    loadedMembers.append(TeamMember(id: memberId, name: memberId, email: ""))
                }
            }
            
            members = loadedMembers
            isLoading = false
        } catch {
            print("Error loading members: \(error)")
            isLoading = false
        }
    }
    
    private func removeMember(_ member: TeamMember) async {
        await teamManager.removeMember(memberId: member.id, fromTeam: team)
        await loadMembers()
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let name: String
    let role: String
    let isLeader: Bool
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(isLeader ? Color.accentBrand : Color(red: 0.4, green: 0.6, blue: 0.9))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                
                Text(role)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondaryText)
            }
            
            Spacer()
            
            // Botón eliminar (solo para miembros, no líder)
            if !isLeader, let onRemove = onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Team Member Model

struct TeamMember: Identifiable {
    let id: String
    let name: String
    let email: String
}


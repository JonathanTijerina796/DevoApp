//
//  ContentView.swift
//  DevoApp
//
//  Created by Jona on 11/08/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var teamManager = TeamManager()
    @State private var showSplash = true
    
    // 🚨 DEBUG: Cambiar a true para saltar splash temporalmente
    private let debugSkipSplash = false
    
    var body: some View {
        Group {
            if showSplash && !debugSkipSplash {
                SplashView {
                    print("🔥 Splash completed, transitioning to login")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            } else {
                if authManager.isSignedIn {
                    // Siempre mostrar TabBar con Home y Perfil (aunque no tenga equipo),
                    // para permitir acceso a Perfil/Settings.
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(teamManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
        .onChange(of: teamManager.currentTeam) { oldValue, newValue in
            // Detectar cambios en currentTeam para actualizar la vista
            print("🔄 [ContentView] currentTeam cambió: \(oldValue?.name ?? "nil") -> \(newValue?.name ?? "nil")")
            if newValue != nil && oldValue == nil {
                print("✅ [ContentView] Equipo cargado, navegando a MainTabView")
            }
        }
        .onAppear {
            print("🚀 ContentView appeared, showSplash: \(showSplash), isSignedIn: \(authManager.isSignedIn)")
            
            // Skip splash in debug mode
            if debugSkipSplash {
                showSplash = false
            }
            
            // Cargar equipos cuando el usuario está autenticado
            if authManager.isSignedIn {
                Task {
                    await teamManager.loadAllUserTeams()
                }
            }
        }
        .onChange(of: authManager.isSignedIn) { oldValue, newValue in
            if newValue {
                Task {
                    await teamManager.loadAllUserTeams()
                    // Limpiar devocionales vencidos cuando el usuario inicia sesión
                    await teamManager.cleanupExpiredDevotionals()
                }
            } else {
                teamManager.currentTeam = nil
                teamManager.allTeams = []
                teamManager.stopListening()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamCreated"))) { _ in
            print("📢 [ContentView] Notificación TeamCreated recibida, recargando equipos...")
            Task {
                await teamManager.loadAllUserTeams()
                print("✅ [ContentView] Equipos recargados, currentTeam: \(teamManager.currentTeam?.name ?? "nil")")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamJoined"))) { _ in
            Task {
                await teamManager.loadAllUserTeams()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamUpdated"))) { _ in
            Task {
                await teamManager.loadAllUserTeams()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamDeleted"))) { _ in
            // Cuando se elimina el equipo, recargar equipos para ver si hay otros
            // No limpiar currentTeam aquí porque loadAllUserTeams() ya lo maneja
            print("📢 [ContentView] Notificación TeamDeleted recibida, recargando equipos...")
            Task {
                await teamManager.loadAllUserTeams()
                print("✅ [ContentView] Equipos recargados después de eliminar. currentTeam: \(teamManager.currentTeam?.name ?? "ninguno")")
            }
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                
                Text(NSLocalizedString("hello_world", comment: ""))
                    .font(.title)
                
                if let user = authManager.user {
                    Text("Welcome, \(user.displayName ?? user.email ?? "User")!")
                        .font(.headline)
                }
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("DevoApp")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

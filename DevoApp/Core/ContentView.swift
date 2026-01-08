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
                    // Si tiene equipo, mostrar TabBar con Home y Perfil
                    if teamManager.currentTeam != nil {
                        MainTabView()
                            .environmentObject(authManager)
                            .environmentObject(teamManager)
                    } else {
                        // Si no tiene equipo, mostrar selección
                        TeamSelectionView()
                            .environmentObject(authManager)
                            .onAppear {
                                Task {
                                    await teamManager.loadCurrentUserTeam()
                                }
                            }
                    }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
        .onAppear {
            print("🚀 ContentView appeared, showSplash: \(showSplash), isSignedIn: \(authManager.isSignedIn)")
            
            // Skip splash in debug mode
            if debugSkipSplash {
                showSplash = false
            }
            
            // Cargar equipo cuando el usuario está autenticado
            if authManager.isSignedIn {
                Task {
                    await teamManager.loadCurrentUserTeam()
                }
            }
        }
        .onChange(of: authManager.isSignedIn) { oldValue, newValue in
            if newValue {
                Task {
                    await teamManager.loadCurrentUserTeam()
                }
            } else {
                teamManager.currentTeam = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamCreated"))) { _ in
            Task {
                await teamManager.loadCurrentUserTeam()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamJoined"))) { _ in
            Task {
                await teamManager.loadCurrentUserTeam()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamUpdated"))) { _ in
            Task {
                await teamManager.loadCurrentUserTeam()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TeamDeleted"))) { _ in
            // Cuando se elimina el equipo, limpiar el equipo local
            print("📢 [ContentView] Notificación TeamDeleted recibida, limpiando equipo...")
            teamManager.currentTeam = nil
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

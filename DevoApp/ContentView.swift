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
                    MainAppView()
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

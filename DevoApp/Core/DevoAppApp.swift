//
//  DevoAppApp.swift
//  DevoApp
//
//  Created by Jona on 11/08/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
// import FBSDKCoreKit // Temporalmente deshabilitado

@main
struct DevoAppApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Facebook SDK
        // ApplicationDelegate.shared.application(
        //     UIApplication.shared,
        //     didFinishLaunchingWithOptions: nil
        // ) // Temporalmente deshabilitado
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    // Handle URL schemes for social logins
                    // ApplicationDelegate.shared.application(
                    //     UIApplication.shared,
                    //     open: url,
                    //     sourceApplication: nil,
                    //     annotation: UIApplication.OpenURLOptionsKey.annotation
                    // ) // Temporalmente deshabilitado
                    
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

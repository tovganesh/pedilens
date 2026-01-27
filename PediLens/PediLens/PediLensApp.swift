//
//  PediLensApp.swift
//  PediLens
//
//  Created by PediLens Team
//

import SwiftUI

@main
struct PediLensApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    RoleSelectionView { role in
                        appState.completeOnboarding()
                    }
                }
            }
            .onAppear {
                appState.checkOnboardingStatus()
            }
        }
    }
}

/// App-wide state management
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false
    
    func checkOnboardingStatus() {
        // Check if a user exists in Core Data
        let context = PersistenceController.shared.container.viewContext
        let user = User.fetchCurrentUser(in: context)
        
        // User has completed onboarding if they have a role set in Core Data
        hasCompletedOnboarding = user != nil
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

//
//  ContentView.swift
//  PediLens
//
//  Created by PediLens Team
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var userManager = UserManager.shared
    
    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var users: FetchedResults<User>
    
    @State private var isDoctorUnlocked: Bool = false
    
    var currentUser: User? {
        users.first
    }
    
    var body: some View {
        Group {
            if let user = currentUser, let role = userManager.currentUserRole {
                switch role {
                case .doctor:
                    if isDoctorUnlocked {
                        PatientListView(user: user)
                    } else {
                        DoctorBiometricLockView(
                            onUnlocked: {
                                isDoctorUnlocked = true
                            },
                            onSwitchRole: {
                                Task {
                                    try? await userManager.setUserRole(.patient)
                                }
                            }
                        )
                    }
                case .patient:
                    WoundListView()
                }
            } else {
                // Fallback if role not set (shouldn't happen after onboarding)
                LoadingView()
            }
        }
        .onAppear {
            userManager.loadCurrentUser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            // Re-lock doctor mode when security session expires
            isDoctorUnlocked = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Re-lock doctor mode when app leaves foreground for security
            if userManager.currentUserRole == .doctor {
                isDoctorUnlocked = false
            }
        }
        .onChange(of: userManager.currentUserRole) { newRole in
            if newRole != .doctor {
                isDoctorUnlocked = false
            }
        }
    }
}

/// Loading view
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

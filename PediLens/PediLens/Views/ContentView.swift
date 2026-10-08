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
    
    var currentUser: User? {
        users.first
    }
    
    var body: some View {
        Group {
            if let user = currentUser, let role = userManager.currentUserRole {
                switch role {
                case .doctor:
                    PatientListView(user: user)
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

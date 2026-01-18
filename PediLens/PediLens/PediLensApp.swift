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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

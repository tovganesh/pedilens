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
    @ScaledMetric private var iconSize: CGFloat = 60
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "cross.case.fill")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                    .font(.system(size: iconSize))
                    .padding()
                    .accessibilityLabel("PediLens app icon")
                    .accessibilityHidden(true) // Decorative image
                
                Text("PediLens")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Diabetic Foot Ulcer Documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .accessibilityLabel("Application for documenting diabetic foot ulcers")
            }
            .navigationTitle("PediLens")
            .accessibilityElement(children: .contain)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

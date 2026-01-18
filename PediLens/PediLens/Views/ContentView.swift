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
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "cross.case.fill")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 60))
                    .padding()
                
                Text("PediLens")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Diabetic Foot Ulcer Documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .navigationTitle("PediLens")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

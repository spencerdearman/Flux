//
//  FluxApp.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

@main
struct FluxApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Flux"
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([
            Area.self,
            Project.self,
            Heading.self,
            TaskItem.self,
            ChecklistItem.self,
            Tag.self,
            TaskTagAssignment.self
        ])
        let modelConfiguration = ModelConfiguration(
            "Flux",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SampleDataSeeder.bootstrapIfNeeded(in: container.mainContext)
            self.sharedModelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

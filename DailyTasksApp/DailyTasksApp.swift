//
//  DailyTasksApp.swift
//  DailyTasksApp
//
//  Created by Spencer Dearman on 4/20/26.
//

import SwiftUI
import SwiftData

@main
struct DailyTasksApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.DailyTasks"
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        
        // Similar to the Mac app, we let iOS perfectly generate its own isolated sandbox footprint locally
        // while routing all transactions exclusively through Apple's CloudKit background synchronization servers dynamically!
        let modelConfiguration = ModelConfiguration(
            "DailyTasks",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )

        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
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

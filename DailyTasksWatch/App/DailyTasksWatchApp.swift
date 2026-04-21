//
//  DailyTasksWatchApp.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI
import SwiftData

@main
struct DailyTasksWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        
        let modelConfiguration = ModelConfiguration("DailyTasks", schema: schema, cloudKitDatabase: .automatic)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            TaskManager.shared.configure(with: container)
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

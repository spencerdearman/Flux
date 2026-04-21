//
//  DailyTasksWidget.swift
//  DailyTasksWidgetExtension
//
//  Created by Spencer Dearman.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: Intent
struct DailyTasksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Tasks"
    static var description = IntentDescription("Select which task data to display.")
    public init() {}
}

// MARK: Entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: DailyTasksIntent
    let taskData: SharedTaskItem
}

// MARK: Provider
struct Provider: AppIntentTimelineProvider {
    typealias Entry = TaskEntry
    typealias Intent = DailyTasksIntent
    
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            configuration: DailyTasksIntent(),
            taskData: SharedTaskItem(completedCount: 2, totalCount: 5)
        )
    }
    
    func snapshot(for configuration: DailyTasksIntent, in context: Context) async -> TaskEntry {
        TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())
    }
    
    func timeline(for configuration: DailyTasksIntent, in context: Context) async -> Timeline<TaskEntry> {
        let entry = TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    func recommendations() -> [AppIntentRecommendation<DailyTasksIntent>] {
        return [AppIntentRecommendation(intent: DailyTasksIntent(), description: "Default")]
    }
    
    private func fetchSharedData() -> SharedTaskItem {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
              let savedData = defaults.data(forKey: SharedConstants.tasksKey),
              let decodedData = try? JSONDecoder().decode(SharedTaskItem.self, from: savedData) else {
            return SharedTaskItem(completedCount: 0, totalCount: 0)
        }
        return decodedData
    }
}

// MARK: Entry View
struct DailyTasksWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        let completed = Double(entry.taskData.completedCount)
        let total = Double(max(entry.taskData.totalCount, 1))
        let left = max(0, entry.taskData.totalCount - entry.taskData.completedCount)
        
        switch family {
        case .accessoryCircular:
            Gauge(value: completed, in: 0...total) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(entry.taskData.completedCount)")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.accentColor)
            
        case .accessoryRectangular:
            HStack {
                VStack(alignment: .leading) {
                    Text("Tasks").font(.headline)
                    Text("\(entry.taskData.completedCount) of \(entry.taskData.totalCount)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Gauge(value: completed, in: 0...total) {
                    Text("")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.accentColor)
            }
            
        case .accessoryInline:
            Text("\(Image(systemName: "checkmark.circle")) \(entry.taskData.completedCount)/\(entry.taskData.totalCount) TASKS • \(left) LEFT")
            
        case .accessoryCorner:
            Text("\(left) LEFT")
                .widgetCurvesContent()
                .widgetLabel {
                    ProgressView(value: completed, total: total)
                        .tint(.accentColor)
                }
            
        default:
            Text("Unsupported")
        }
    }
}

// MARK: Widget
struct DailyTasksWidget: Widget {
    let kind: String = "DailyTasksWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DailyTasksIntent.self, provider: Provider()) { entry in
            DailyTasksWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Tasks Tracker")
        .description("Keep track of your daily task progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

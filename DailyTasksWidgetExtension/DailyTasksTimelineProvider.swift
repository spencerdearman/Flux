import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 1. App Intent
// This is the foundation for future user configuration.
// Add @Parameter properties here later when you want to allow customization.
struct DailyTasksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Tasks"
    static var description = IntentDescription("Select which task data to display.")
    
    // Explicit empty initializer required by protocol
    public init() {}
}

// MARK: - 2. Timeline Entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: DailyTasksIntent
    let taskData: SharedTaskItem
}

// MARK: - 3. Timeline Provider
struct Provider: AppIntentTimelineProvider {
    // 1. Explicitly map the associated types
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
        // Provides a default recommendation to the system to satisfy the protocol
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

// MARK: - 4. Entry View
struct DailyTasksWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        let completed = Double(entry.taskData.completedCount)
        let total = Double(max(entry.taskData.totalCount, 1)) // Prevent divide by zero
        
        switch family {
        case .accessoryCircular:
            Gauge(value: completed, in: 0...total) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(entry.taskData.completedCount)")
            }
            .gaugeStyle(.accessoryCircular)
            
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
            }
            
        case .accessoryInline:
            Text("\(Image(systemName: "checkmark.circle")) \(entry.taskData.completedCount)/\(entry.taskData.totalCount) Done")
            
        case .accessoryCorner:
            Text("\(entry.taskData.completedCount)")
                .widgetLabel {
                    Gauge(value: completed, in: 0...total) {
                        Text("Tasks")
                    }
                }
            
        default:
            Text("Unsupported")
        }
    }
}

// MARK: - 5. Widget Configuration
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

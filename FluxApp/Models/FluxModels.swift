import Foundation
import SwiftData

enum FluxTaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case someday
    case completed

    var id: String { rawValue }
}

enum FluxSidebarSelection: Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case area(UUID)
    case project(UUID)
}

@Model
final class FluxArea {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var symbolName: String = "square.grid.2x2"
    var tintHex: String = "#5B83B7"
    var sortOrder: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \FluxProject.area)
    var projects: [FluxProject]?

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.area)
    var tasks: [FluxTask]?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        symbolName: String = "square.grid.2x2",
        tintHex: String = "#5B83B7",
        sortOrder: Double = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.symbolName = symbolName
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.projects = []
        self.tasks = []
    }
}

@Model
final class FluxProject {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var goalSummary: String = ""
    var tintHex: String = "#2E6BC6"
    var sortOrder: Double = 0

    var area: FluxArea?

    @Relationship(deleteRule: .cascade, inverse: \FluxHeading.project)
    var headings: [FluxHeading]?

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.project)
    var tasks: [FluxTask]?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        goalSummary: String = "",
        tintHex: String = "#2E6BC6",
        sortOrder: Double = 0,
        area: FluxArea? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goalSummary = goalSummary
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.area = area
        self.headings = []
        self.tasks = []
    }
}

@Model
final class FluxHeading {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var sortOrder: Double = 0

    var project: FluxProject?

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.heading)
    var tasks: [FluxTask]?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        sortOrder: Double = 0,
        project: FluxProject? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.project = project
        self.tasks = []
    }
}

@Model
final class FluxTag {
    var id: UUID = UUID()
    var title: String = ""
    var symbolName: String = "tag"
    var tintHex: String = "#8897AA"

    @Relationship(deleteRule: .cascade, inverse: \FluxTaskTagAssignment.tag)
    var taskAssignments: [FluxTaskTagAssignment]?

    static let colorPalette: [String] = [
        "#E8574A", "#E8953A", "#E5C445", "#5BBD6B",
        "#46A0D5", "#9B6FD1", "#D96BA0", "#6BC4C4"
    ]

    static func nextColor(forIndex index: Int) -> String {
        colorPalette[index % colorPalette.count]
    }

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "tag",
        tintHex: String = "#8897AA"
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.tintHex = tintHex
    }
}

@Model
final class FluxChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Double = 0

    var task: FluxTask?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Double = 0,
        task: FluxTask? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.task = task
    }
}

@Model
final class FluxTaskTagAssignment {
    var id: UUID = UUID()
    var task: FluxTask?
    var tag: FluxTag?

    init(
        id: UUID = UUID(),
        task: FluxTask? = nil,
        tag: FluxTag? = nil
    ) {
        self.id = id
        self.task = task
        self.tag = tag
    }
}

@Model
final class FluxTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var whenDate: Date?
    var deadline: Date?
    var completedAt: Date?
    var statusRaw: String = FluxTaskStatus.active.rawValue
    var isInInbox: Bool = true
    var isEvening: Bool = false
    var sortOrder: Double = 0
    var recurrenceRule: String?

    var area: FluxArea?
    var project: FluxProject?
    var heading: FluxHeading?

    @Relationship(deleteRule: .cascade, inverse: \FluxTaskTagAssignment.task)
    var tagAssignments: [FluxTaskTagAssignment]?

    @Relationship(deleteRule: .cascade, inverse: \FluxChecklistItem.task)
    var checklist: [FluxChecklistItem]?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        whenDate: Date? = nil,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        status: FluxTaskStatus = .active,
        isInInbox: Bool = true,
        isEvening: Bool = false,
        sortOrder: Double = 0,
        recurrenceRule: String? = nil,
        area: FluxArea? = nil,
        project: FluxProject? = nil,
        heading: FluxHeading? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.whenDate = whenDate
        self.deadline = deadline
        self.completedAt = completedAt
        self.statusRaw = status.rawValue
        self.isInInbox = isInInbox
        self.isEvening = isEvening
        self.sortOrder = sortOrder
        self.recurrenceRule = recurrenceRule
        self.area = area
        self.project = project
        self.heading = heading
        self.tagAssignments = []
        self.checklist = []
    }
}

extension FluxTask {
    var status: FluxTaskStatus {
        get { FluxTaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isCompleted: Bool {
        status == .completed
    }

    var effectiveDate: Date? {
        whenDate ?? deadline
    }

    var tagList: [FluxTag] {
        tagAssignments?.compactMap(\.tag) ?? []
    }

    var tagAssignmentList: [FluxTaskTagAssignment] {
        tagAssignments ?? []
    }

    var checklistItems: [FluxChecklistItem] {
        checklist ?? []
    }

    var recurrenceDescription: String? {
        guard let rule = recurrenceRule else { return nil }
        switch rule {
        case "daily": return "Every day"
        case "weekly": return "Every week"
        case "biweekly": return "Every 2 weeks"
        case "monthly": return "Every month"
        case "yearly": return "Every year"
        default: return rule
        }
    }

    func markComplete() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    func reopen() {
        status = .active
        completedAt = nil
        updatedAt = Date()
    }
}

extension FluxArea {
    var projectList: [FluxProject] {
        projects ?? []
    }

    var taskList: [FluxTask] {
        tasks ?? []
    }

    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted && $0.project == nil }.count
            + projectList.reduce(0) { $0 + $1.activeTaskCount }
    }
}

extension FluxProject {
    var headingList: [FluxHeading] {
        headings ?? []
    }

    var taskList: [FluxTask] {
        tasks ?? []
    }

    var sortedHeadings: [FluxHeading] {
        headingList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var sortedTasks: [FluxTask] {
        taskList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted }.count
    }

    var completionRatio: Double {
        guard !taskList.isEmpty else { return 0 }
        return Double(taskList.filter(\.isCompleted).count) / Double(taskList.count)
    }
}

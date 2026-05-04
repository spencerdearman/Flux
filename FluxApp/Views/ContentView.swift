import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]
    @Query(sort: \FluxTask.createdAt, order: .reverse) private var tasks: [FluxTask]

    @State private var quickEntrySelection: FluxSidebarSelection?
    @State private var showingQuickEntry = false
    @State private var showQuickFind = false
    @State private var quickFindPath: [FluxSidebarSelection] = []

    var body: some View {
        NavigationStack(path: $quickFindPath) {
            List {
                // Quick Find search button
                Button {
                    showQuickFind = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Quick Find")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

                Section("Core") {
                    coreLink("Inbox", systemImage: "tray.fill", selection: .inbox, count: inboxTasks.count)
                    coreLink("Today", systemImage: "sun.max.fill", selection: .today, count: todayTasks.count)
                    coreLink("Upcoming", systemImage: "calendar", selection: .upcoming, count: upcomingTasks.count)
                    coreLink("Open", systemImage: "tray.2.fill", selection: .anytime, count: anytimeTasks.count)
                    coreLink("Later", systemImage: "moon.zzz.fill", selection: .someday, count: somedayTasks.count)
                    coreLink("Done", systemImage: "checkmark.circle.fill", selection: .logbook, count: logbookTasks.count)
                }

                Section("Areas") {
                    ForEach(filteredAreas) { area in
                        NavigationLink(value: FluxSidebarSelection.area(area.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: area.symbolName)
                                    .foregroundStyle(Color(hex: area.tintHex))
                                    .frame(width: 18)
                                Text(area.title)
                                Spacer()
                                Text("\(area.activeTaskCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(filteredProjects(in: area)) { project in
                            NavigationLink(value: FluxSidebarSelection.project(project.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "paperplane")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                    Text(project.title)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(project.activeTaskCount)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Flux")
            .scrollContentBackground(.hidden)
            .background(FluxBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        quickEntrySelection = .inbox
                        showingQuickEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingQuickEntry) {
                FluxQuickEntrySheet(defaultSelection: quickEntrySelection)
            }
            .navigationDestination(for: FluxSidebarSelection.self) { selection in
                destination(for: selection)
            }
        }
        .tint(.primary)
        .overlay {
            if showQuickFind {
                FluxQuickFindOverlay(
                    areas: areas,
                    projects: projects,
                    tasks: tasks,
                    onSelectSidebar: { sel in
                        showQuickFind = false
                        quickFindPath = [sel]
                    },
                    onSelectTask: { task in
                        showQuickFind = false
                        if let project = task.project {
                            quickFindPath = [.project(project.id)]
                        } else if let area = task.area {
                            quickFindPath = [.area(area.id)]
                        } else if task.isInInbox {
                            quickFindPath = [.inbox]
                        }
                    },
                    onDismiss: {
                        showQuickFind = false
                    }
                )
            }
        }
    }

    private func coreLink(_ title: String, systemImage: String, selection: FluxSidebarSelection, count: Int) -> some View {
        NavigationLink(value: selection) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func destination(for selection: FluxSidebarSelection) -> some View {
        switch selection {
            case .inbox:
                FluxTaskListScreen(title: "Inbox", tasks: inboxTasks, defaultSelection: .inbox)
            case .today:
                FluxTaskListScreen(title: "Today", tasks: todayTasks + eveningTasks, defaultSelection: .today)
            case .upcoming:
                FluxTaskListScreen(title: "Upcoming", tasks: upcomingTasks, defaultSelection: .upcoming)
            case .anytime:
                FluxTaskListScreen(title: "Open", tasks: anytimeTasks, defaultSelection: .anytime)
            case .someday:
                FluxTaskListScreen(title: "Later", tasks: somedayTasks, defaultSelection: .someday)
            case .logbook:
                FluxTaskListScreen(title: "Done", tasks: logbookTasks, defaultSelection: .logbook)
            case .area(let id):
                if let area = areas.first(where: { $0.id == id }) {
                    FluxAreaScreen(area: area, tasks: tasksForArea(area))
                } else {
                    ContentUnavailableView("Area unavailable", systemImage: "rectangle.stack.badge.minus")
                }
            case .project(let id):
                if let project = projects.first(where: { $0.id == id }) {
                    FluxProjectScreen(project: project)
                } else {
                    ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
                }
        }
    }

    private var filteredAreas: [FluxArea] { areas }

    private func filteredProjects(in area: FluxArea) -> [FluxProject] {
        projects.filter { $0.area?.id == area.id }
    }

    private var inboxTasks: [FluxTask] { activeTasks.filter(\.isInInbox) }

    private var todayTasks: [FluxTask] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && !$0.isEvening
        }
    }

    private var eveningTasks: [FluxTask] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && $0.isEvening
        }
    }

    private var upcomingTasks: [FluxTask] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return activeTasks.filter {
            guard let date = $0.effectiveDate else { return false }
            return date >= tomorrow
        }
    }

    private var anytimeTasks: [FluxTask] { activeTasks.filter { !$0.isInInbox && $0.whenDate == nil } }
    private var somedayTasks: [FluxTask] { tasks.filter { $0.status == .someday } }
    private var logbookTasks: [FluxTask] {
        tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    private var activeTasks: [FluxTask] { tasks.filter { $0.status == .active } }

    private func tasksForArea(_ area: FluxArea) -> [FluxTask] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }
}

private struct FluxTaskListScreen: View {
    let title: String
    let tasks: [FluxTask]
    let defaultSelection: FluxSidebarSelection?

    @State private var showingQuickEntry = false
    @State private var editingTask: FluxTask?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FluxHeaderCard(title: title)

                if tasks.isEmpty {
                    FluxEmptyCard(title: title)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(tasks) { task in
                            FluxTaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(FluxBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            FluxQuickEntrySheet(defaultSelection: defaultSelection)
        }
        .sheet(item: $editingTask) { task in
            FluxTaskEditorSheet(task: task)
        }
    }
}

private struct FluxAreaScreen: View {
    let area: FluxArea
    let tasks: [FluxTask]

    @State private var showingQuickEntry = false
    @State private var editingTask: FluxTask?

    private var looseTasks: [FluxTask] {
        tasks.filter { $0.project == nil && !$0.isCompleted }
    }

    private var sortedProjects: [FluxProject] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FluxHeaderCard(title: area.title)

                if !looseTasks.isEmpty {
                    FluxSectionCard(title: "Tasks", count: looseTasks.count) {
                        ForEach(looseTasks) { task in
                            FluxTaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }

                if !sortedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects")
                            .font(.title3.weight(.semibold))
                        ForEach(sortedProjects) { project in
                            NavigationLink(value: FluxSidebarSelection.project(project.id)) {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if !project.goalSummary.isEmpty {
                                            Text(project.goalSummary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Text("\(project.activeTaskCount) active")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.06), in: Capsule())
                                }
                                .padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(FluxBackground())
        .navigationTitle(area.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            FluxQuickEntrySheet(defaultSelection: .area(area.id))
        }
        .sheet(item: $editingTask) { task in
            FluxTaskEditorSheet(task: task)
        }
    }
}

private struct FluxProjectScreen: View {
    let project: FluxProject

    @State private var showingQuickEntry = false
    @State private var editingTask: FluxTask?

    private var ungroupedTasks: [FluxTask] {
        project.sortedTasks.filter { $0.heading == nil && !$0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FluxHeaderCard(title: project.title)

                if !project.notes.isEmpty {
                    Text(project.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if !ungroupedTasks.isEmpty {
                    FluxSectionCard(title: "Tasks", count: ungroupedTasks.count) {
                        ForEach(ungroupedTasks) { task in
                            FluxTaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }

                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id && !$0.isCompleted }
                    if !headingTasks.isEmpty {
                        FluxSectionCard(title: heading.title, count: headingTasks.count) {
                            ForEach(headingTasks) { task in
                                FluxTaskCard(task: task) {
                                    editingTask = task
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(FluxBackground())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            FluxQuickEntrySheet(defaultSelection: .project(project.id))
        }
        .sheet(item: $editingTask) { task in
            FluxTaskEditorSheet(task: task)
        }
    }
}

private struct FluxTaskCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: FluxTask
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                if task.isCompleted {
                    task.reopen()
                } else {
                    task.markComplete()
                }
                try? modelContext.save()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !task.tagList.isEmpty || task.area != nil || task.project != nil || task.effectiveDate != nil || !task.checklistItems.isEmpty {
                        FluxTaskMeta(task: task)
                    }

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                if task.isCompleted {
                    task.reopen()
                } else {
                    task.markComplete()
                }
                try? modelContext.save()
            }
        }
    }
}

private struct FluxTaskMeta: View {
    let task: FluxTask

    var body: some View {
        FlowLayout(spacing: 6) {
            if let project = task.project {
                FluxBadge(text: project.title, tint: project.tintHex)
            } else if let area = task.area {
                FluxBadge(text: area.title, tint: area.tintHex)
            }

            if let date = task.whenDate {
                FluxDateBadge(date: date, isDeadline: false)
            }

            if let deadline = task.deadline {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text(deadlineLabel(deadline))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }

            ForEach(task.tagList.prefix(3)) { tag in
                FluxBadge(text: tag.title, tint: tag.tintHex)
            }

            if !task.checklistItems.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(task.checklistItems.filter(\.isCompleted).count)/\(task.checklistItems.count)")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
    }

    private func deadlineLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        if hour == 0 && minute == 0 {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute())
    }
}

private struct FluxTaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]

    @Bindable var task: FluxTask
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title & Notes
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Task title", text: $task.title)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        TextField("Add notes…", text: $task.notes, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2...10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Subtasks
                    if !task.checklistItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        item.isCompleted.toggle()
                                        try? modelContext.save()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                                            .font(.title3)
                                        Text(item.title)
                                            .strikethrough(item.isCompleted)
                                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if item.id != task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder }).last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    // Move to section
                    VStack(alignment: .leading, spacing: 0) {
                        // Area
                        HStack {
                            Label("Area", systemImage: "square.grid.2x2")
                                .foregroundStyle(.primary)
                            Spacer()
                            Picker("", selection: areaBinding) {
                                Text("Inbox").tag(UUID?.none)
                                ForEach(areas) { area in
                                    Text(area.title).tag(Optional(area.id))
                                }
                            }
                            .labelsHidden()
                            .tint(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 52)

                        // Project
                        HStack {
                            Label("Project", systemImage: "paperplane")
                                .foregroundStyle(.primary)
                            Spacer()
                            Picker("", selection: projectBinding) {
                                Text("None").tag(UUID?.none)
                                ForEach(filteredProjects) { project in
                                    Text(project.title).tag(Optional(project.id))
                                }
                            }
                            .labelsHidden()
                            .tint(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Schedule section
                    VStack(alignment: .leading, spacing: 0) {
                        // When
                        HStack {
                            Label("When", systemImage: "calendar")
                                .foregroundStyle(.primary)
                            Spacer()
                            if task.whenDate != nil {
                                Button {
                                    task.whenDate = nil
                                    task.isEvening = false
                                    task.updatedAt = .now
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            DatePicker("", selection: whenBinding, displayedComponents: .date)
                                .labelsHidden()
                                .fixedSize()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 52)

                        // This Evening
                        Toggle(isOn: $task.isEvening) {
                            Label("This Evening", systemImage: "moon.fill")
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 52)

                        // Deadline
                        HStack {
                            Label("Deadline", systemImage: "flag.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if task.deadline != nil {
                                Button {
                                    task.deadline = nil
                                    task.updatedAt = .now
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            DatePicker("", selection: deadlineBinding, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .fixedSize()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Task", systemImage: "trash")
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(task.title.isEmpty ? "Task" : task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        task.updatedAt = .now
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(task)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }

    private var filteredProjects: [FluxProject] {
        guard let areaID = task.area?.id else { return [] }
        return projects.filter { $0.area?.id == areaID }
    }

    private var areaBinding: Binding<UUID?> {
        Binding(
            get: { task.area?.id },
            set: { newValue in
                task.area = areas.first(where: { $0.id == newValue })
                if let area = task.area {
                    task.isInInbox = false
                    if let project = task.project, project.area?.id != area.id {
                        task.project = nil
                    }
                } else {
                    task.project = nil
                    task.isInInbox = true
                }
                task.updatedAt = .now
            }
        )
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { task.project?.id },
            set: { newValue in
                task.project = projects.first(where: { $0.id == newValue })
                if let project = task.project {
                    task.area = project.area
                    task.isInInbox = false
                }
                task.updatedAt = .now
            }
        )
    }

    private var whenBinding: Binding<Date> {
        Binding(
            get: { task.whenDate ?? .now },
            set: {
                task.whenDate = Calendar.current.startOfDay(for: $0)
                task.status = .active
                task.updatedAt = .now
            }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { task.deadline ?? .now },
            set: {
                task.deadline = $0
                task.updatedAt = .now
            }
        )
    }
}

private struct FluxQuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]

    let defaultSelection: FluxSidebarSelection?

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var whenDate: Date?
    @State private var deadline: Date?
    @State private var isEvening = false
    @State private var status: FluxTaskStatus = .active

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("New task", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Placement") {
                    Picker("Area", selection: $selectedAreaID) {
                        Text("Inbox").tag(UUID?.none)
                        ForEach(areas) { area in
                            Text(area.title).tag(Optional(area.id))
                        }
                    }

                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(UUID?.none)
                        ForEach(filteredProjects) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    .disabled(selectedAreaID == nil)
                }

                Section("Timing") {
                    Picker("Status", selection: $status) {
                        Text("Active").tag(FluxTaskStatus.active)
                        Text("Later").tag(FluxTaskStatus.someday)
                    }

                    Toggle("This Evening", isOn: $isEvening)
                    DatePicker("When", selection: whenBinding, displayedComponents: .date)
                    DatePicker("Deadline", selection: deadlineBinding, displayedComponents: [.date, .hourAndMinute])

                    Button("Clear When") {
                        whenDate = nil
                        isEvening = false
                    }

                    Button("Clear Deadline") {
                        deadline = nil
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: applyDefaultSelection)
        }
    }

    private var filteredProjects: [FluxProject] {
        guard let selectedAreaID else { return [] }
        return projects.filter { $0.area?.id == selectedAreaID }
    }

    private var whenBinding: Binding<Date> {
        Binding(
            get: { whenDate ?? .now },
            set: { whenDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { deadline ?? .now },
            set: { deadline = $0 }
        )
    }

    private func applyDefaultSelection() {
        guard selectedAreaID == nil, selectedProjectID == nil else { return }

        switch defaultSelection {
        case .area(let id):
            selectedAreaID = id
        case .project(let id):
            selectedProjectID = id
            selectedAreaID = projects.first(where: { $0.id == id })?.area?.id
        case .someday:
            status = .someday
        default:
            break
        }
    }

    private func saveTask() {
        let project = projects.first(where: { $0.id == selectedProjectID })
        let area = project?.area ?? areas.first(where: { $0.id == selectedAreaID })
        let task = FluxTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            whenDate: whenDate,
            deadline: deadline,
            status: status,
            isInInbox: area == nil && project == nil,
            isEvening: isEvening,
            sortOrder: Double((project?.taskList.count ?? area?.taskList.count ?? 0)),
            area: area,
            project: project
        )
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}

private struct FluxSectionCard<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                content
            }
        }
    }
}

private struct FluxHeaderCard: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct FluxEmptyCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing in \(title.lowercased()) right now.")
                .font(.title3.weight(.semibold))
            Text("Use the add button to capture something new.")
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct FluxBadge: View {
    let text: String
    let tint: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(hex: tint))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: tint).opacity(0.12), in: Capsule())
    }
}

private struct FluxDateBadge: View {
    let date: Date
    let isDeadline: Bool

    var body: some View {
        Text(date.formatted(.dateTime.month(.abbreviated).day()))
            .font(.caption.weight(.medium))
            .foregroundStyle(isDeadline ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(isDeadline ? 0.10 : 0.06), in: Capsule())
    }
}

// MARK: - Quick Find Sheet

private struct FluxQuickFindOverlay: View {
    let areas: [FluxArea]
    let projects: [FluxProject]
    let tasks: [FluxTask]
    let onSelectSidebar: (FluxSidebarSelection) -> Void
    let onSelectTask: (FluxTask) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var coreListResults: [(String, String, Color, FluxSidebarSelection)] {
        let lists: [(String, String, Color, FluxSidebarSelection)] = [
            ("Inbox", "tray.fill", .primary, .inbox),
            ("Today", "sun.max.fill", .yellow, .today),
            ("Upcoming", "calendar", .red, .upcoming),
            ("Open", "tray.2.fill", .blue, .anytime),
            ("Later", "moon.zzz.fill", .purple, .someday),
            ("Done", "checkmark.circle.fill", .green, .logbook),
        ]
        guard !query.isEmpty else { return lists }
        return lists.filter { $0.0.localizedCaseInsensitiveContains(query) }
    }

    private var areaResults: [FluxArea] {
        guard !query.isEmpty else { return areas }
        return areas.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var projectResults: [FluxProject] {
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var taskResults: [FluxTask] {
        guard !query.isEmpty else { return [] }
        return tasks.filter { !$0.isCompleted && $0.title.localizedCaseInsensitiveContains(query) }
            .prefix(10).map { $0 }
    }

    private var allEmpty: Bool {
        coreListResults.isEmpty && areaResults.isEmpty && projectResults.isEmpty && taskResults.isEmpty
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Quick Find", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .focused($isFocused)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !coreListResults.isEmpty {
                            quickFindSection("Lists", items: coreListResults.map { item in
                                (id: "list-\(item.0)", icon: item.1, color: item.2, title: item.0, subtitle: nil as String?, action: { onSelectSidebar(item.3) })
                            })
                        }
                        if !areaResults.isEmpty {
                            quickFindSection("Areas", items: areaResults.map { area in
                                (id: "area-\(area.id)", icon: area.symbolName, color: Color(hex: area.tintHex), title: area.title, subtitle: nil as String?, action: { onSelectSidebar(.area(area.id)) })
                            })
                        }
                        if !projectResults.isEmpty {
                            quickFindSection("Projects", items: projectResults.map { project in
                                (id: "project-\(project.id)", icon: "paperplane", color: Color(hex: project.tintHex), title: project.title, subtitle: project.area?.title, action: { onSelectSidebar(.project(project.id)) })
                            })
                        }
                        if !taskResults.isEmpty {
                            quickFindSection("Tasks", items: taskResults.map { task in
                                (id: "task-\(task.id)", icon: "circle", color: Color.secondary, title: task.title, subtitle: task.project?.title ?? task.area?.title, action: { onSelectTask(task) })
                            })
                        }
                        if allEmpty {
                            Text("No results")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 400)
            }
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
        }
    }

    private func quickFindSection(_ title: String, items: [(id: String, icon: String, color: Color, title: String, subtitle: String?, action: () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(items, id: \.id) { item in
                Button {
                    item.action()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.color)
                            .frame(width: 22, height: 22)
                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FluxBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white, Color(white: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 91, 131, 183)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

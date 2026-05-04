//
//  ContentView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var calendarStore: FluxCalendarStore

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]
    @Query(sort: \FluxTask.createdAt, order: .reverse) private var tasks: [FluxTask]

    @State private var selection: FluxSidebarSelection? = .inbox
    @State private var showQuickEntrySheet = false
    @State private var showNewProjectSheet = false
    @State private var showNewAreaSheet = false
    @State private var showSettingsSheet = false
    @State private var expandedTaskID: UUID?
    @State private var completingTaskIDs: Set<UUID> = []
    @State private var showQuickFind = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContainer
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showQuickEntrySheet) {
            QuickEntryView(defaultSelection: selection)
        }
        .sheet(isPresented: $showNewProjectSheet) {
            NewProjectSheet()
        }
        .sheet(isPresented: $showNewAreaSheet) {
            NewAreaSheet()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet()
        }
        .tint(.primary)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if case .project(let id) = selection {
                    Button {
                        openWindow(value: id)
                    } label: {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open in Window")
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white, Color(white: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            calendarStore.refresh()
        }
        .focusedSceneValue(\.selectedProjectID, selectedProjectID)
        .overlay {
            if showQuickFind {
                FluxQuickFindOverlay(
                    areas: areas,
                    projects: projects,
                    tasks: tasks,
                    onSelectSidebar: { sel in
                        selection = sel
                        showQuickFind = false
                    },
                    onSelectTask: { task in
                        // Navigate to the task's context and expand it
                        if let project = task.project {
                            selection = .project(project.id)
                        } else if let area = task.area {
                            selection = .area(area.id)
                        } else if task.isInInbox {
                            selection = .inbox
                        } else if task.status == .someday {
                            selection = .someday
                        } else {
                            selection = .anytime
                        }
                        expandedTaskID = task.id
                        showQuickFind = false
                    },
                    onDismiss: {
                        showQuickFind = false
                    }
                )
            }
        }
        .background {
            Button("") { showQuickFind.toggle() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            // Quick Find button
            Button {
                showQuickFind = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Quick Find")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘F")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .listRowSeparator(.hidden)

            Section("Core") {
                navLink("Inbox", systemImage: "tray.fill", selection: .inbox, count: inboxTasks.count)
                navLink("Today", systemImage: "sun.max.fill", selection: .today, count: todayTasks.count)
                navLink("Upcoming", systemImage: "calendar", selection: .upcoming, count: upcomingTasks.count)
                navLink("Open", systemImage: "tray.2.fill", selection: .anytime, count: anytimeTasks.count)
                navLink("Later", systemImage: "moon.zzz.fill", selection: .someday, count: somedayTasks.count)
                navLink("Done", systemImage: "checkmark.circle.fill", selection: .logbook, count: logbookTasks.count)
            }

            Section("Areas") {
                ForEach(filteredAreas) { area in
                    // Area row — tapping navigates to area detail
                    NavigationLink(value: FluxSidebarSelection.area(area.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: area.symbolName)
                                .foregroundStyle(Color(hex: area.tintHex))
                            Text(area.title)
                            Spacer()
                            Text("\(area.activeTaskCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        _ = reassign(tasks: items, to: area)
                    }

                    // Projects under the area (indented)
                    ForEach(filteredProjects(in: area)) { project in
                        NavigationLink(value: FluxSidebarSelection.project(project.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: "paperplane")
                                Text(project.title)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(project.activeTaskCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 20)
                        .dropDestination(for: String.self) { items, _ in
                            _ = reassign(tasks: items, to: project, in: area)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button {
                        showNewProjectSheet = true
                    } label: {
                        Label("New Project", systemImage: "list.bullet")
                    }

                    Divider()

                    Button {
                        showNewAreaSheet = true
                    } label: {
                        Label("New Area", systemImage: "square.grid.2x2")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New List")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Spacer()

                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(10)
        }
    }

    // MARK: - Detail

    private var detailContainer: some View {
        detailContent
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 0) {
                    detailFooterTab(systemImage: "plus", label: "New") {
                        showQuickEntrySheet = true
                    }
                    detailFooterTab(systemImage: "calendar", label: "Today") {
                        selection = .today
                    }
                    detailFooterTab(systemImage: "arrow.down.circle", label: "Import") {
                        calendarStore.importReminders(into: modelContext, areas: areas)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                .padding(.horizontal, 20)
                .frame(maxWidth: 260)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
                .padding(.bottom, 12)
            }
    }

    private func detailFooterTab(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .inbox {
            case .inbox:
                FluxTaskCollectionView(
                    title: "Inbox",
                    tasks: inboxTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .today:
                FluxTaskCollectionView(
                    title: "Today",
                    tasks: todayTasks,
                    eveningTasks: eveningTasks,
                    events: calendarStore.todayEvents,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .upcoming:
                FluxTaskCollectionView(
                    title: "Upcoming",
                    tasks: upcomingTasks,
                    events: calendarStore.upcomingEvents,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .anytime:
                FluxTaskCollectionView(
                    title: "Open",
                    tasks: anytimeTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .someday:
                FluxTaskCollectionView(
                    title: "Later",
                    tasks: somedayTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .logbook:
                FluxTaskCollectionView(
                    title: "Done",
                    tasks: logbookTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .area(let id):
                if let area = areas.first(where: { $0.id == id }) {
                    FluxAreaDetailView(
                        area: area,
                        tasks: tasksForArea(area),
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs,
                        selection: $selection
                    )
                } else {
                    ContentUnavailableView("Area unavailable", systemImage: "rectangle.stack.badge.minus")
                }
            case .project(let id):
                if let project = projects.first(where: { $0.id == id }) {
                    FluxProjectDetailView(
                        project: project,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    )
                } else {
                    ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
                }
            }
    }

    // MARK: - Data

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

    private var selectedProjectID: UUID? {
        if case .project(let id) = selection { return id }
        return nil
    }

    private func tasksForArea(_ area: FluxArea) -> [FluxTask] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }

    // MARK: - Actions

    private func toggleTask(_ task: FluxTask) {
        if completingTaskIDs.contains(task.id) {
            // User tapped again while completing — undo
            withAnimation(.easeInOut(duration: 0.25)) {
                _ = completingTaskIDs.remove(task.id)
            }
            return
        }

        if task.isCompleted {
            // Reopen immediately
            task.reopen()
            try? modelContext.save()
        } else {
            // Show completed look immediately, but delay actual status change
            withAnimation(.easeInOut(duration: 0.25)) {
                completingTaskIDs.insert(task.id)
            }

            // After a few seconds, actually mark complete and remove from list
            let taskID = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // Only if still in completing set (user didn't undo)
                guard completingTaskIDs.contains(taskID) else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = completingTaskIDs.remove(taskID)
                    task.markComplete()
                    try? modelContext.save()
                }
            }
        }
    }

    private func reassign(tasks ids: [String], to area: FluxArea) -> Bool {
        let matchedTasks = tasks.filter { ids.contains($0.id.uuidString) }
        for task in matchedTasks {
            task.area = area
            task.project = nil
            task.heading = nil
            task.isInInbox = false
            task.updatedAt = .now
        }
        try? modelContext.save()
        return !matchedTasks.isEmpty
    }

    private func reassign(tasks ids: [String], to project: FluxProject, in area: FluxArea) -> Bool {
        let matchedTasks = tasks.filter { ids.contains($0.id.uuidString) }
        for task in matchedTasks {
            task.area = area
            task.project = project
            task.heading = nil
            task.isInInbox = false
            task.updatedAt = .now
        }
        try? modelContext.save()
        return !matchedTasks.isEmpty
    }

    // MARK: - Helpers

    private func navLink(_ title: String, systemImage: String, selection: FluxSidebarSelection, count: Int) -> some View {
        NavigationLink(value: selection) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

}

// MARK: - Task Collection View

private struct FluxTaskCollectionView: View {
    let title: String
    let tasks: [FluxTask]
    var eveningTasks: [FluxTask] = []
    let events: [FluxCalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (FluxTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FluxHeaderCard(title: title)

                if !events.isEmpty {
                    FluxEventStrip(events: events)
                }

                if tasks.isEmpty && eveningTasks.isEmpty {
                    FluxEmptyState(title: title)
                } else {
                    FluxTaskSection(
                        title: "Tasks",
                        tasks: tasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs,
                        onToggle: onToggle
                    )
                    if !eveningTasks.isEmpty {
                        FluxTaskSection(
                            title: "This Evening",
                            tasks: eveningTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs,
                            onToggle: onToggle
                        )
                    }
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Area Detail View

struct FluxAreaDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let area: FluxArea
    let tasks: [FluxTask]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @Binding var selection: FluxSidebarSelection?

    private var looseTasks: [FluxTask] {
        tasks.filter { $0.project == nil && !$0.isCompleted }
    }

    private var sortedProjects: [FluxProject] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FluxHeaderCard(title: area.title)

                // Loose tasks (not assigned to any project)
                if !looseTasks.isEmpty {
                    FluxTaskSection(
                        title: "Tasks",
                        tasks: looseTasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    ) { task in
                        if task.isCompleted { task.reopen() } else { task.markComplete() }
                        try? modelContext.save()
                    }
                }

                // Projects overview
                if !sortedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        VStack(spacing: 0) {
                            ForEach(sortedProjects) { project in
                                Button {
                                    selection = .project(project.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(project.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        // Progress
                                        HStack(spacing: 8) {
                                            if !project.taskList.isEmpty {
                                                Text("\(project.taskList.filter(\.isCompleted).count)/\(project.taskList.count)")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.secondary)

                                                ProgressView(value: project.completionRatio)
                                                    .frame(width: 48)
                                                    .tint(Color(hex: project.tintHex))
                                            }

                                            Text("\(project.activeTaskCount) active")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.primary.opacity(0.05), in: Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if project.id != sortedProjects.last?.id {
                                    Divider()
                                        .padding(.leading, 18)
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }

                // Show tasks in each project
                ForEach(sortedProjects) { project in
                    let projectTasks = tasks.filter { $0.project?.id == project.id && !$0.isCompleted }
                    if !projectTasks.isEmpty {
                        FluxTaskSection(
                            title: project.title,
                            tasks: projectTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            if task.isCompleted { task.reopen() } else { task.markComplete() }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Project Detail View

struct FluxProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let project: FluxProject
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @State private var newHeadingTitle = ""
    @State private var showAddHeading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(project.title)
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Simple notes editor
                TextField("Notes…", text: Binding(
                    get: { project.notes },
                    set: {
                        project.notes = $0
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(2...10)
                .padding(16)
                .frame(minHeight: 56, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id }
                    VStack(alignment: .leading, spacing: 8) {
                        if headingTasks.isEmpty {
                            // Just show heading title when no tasks
                            HStack {
                                Text(heading.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("0")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            FluxTaskSection(
                                title: heading.title,
                                tasks: headingTasks,
                                expandedTaskID: $expandedTaskID,
                                completingTaskIDs: $completingTaskIDs
                            ) { task in
                                if task.isCompleted { task.reopen() } else { task.markComplete() }
                                try? modelContext.save()
                            }
                        }

                        FluxInlineTaskAdder(
                            project: project,
                            area: project.area,
                            heading: heading
                        )
                    }
                }

                let ungroupedTasks = project.sortedTasks.filter { $0.heading == nil }
                VStack(alignment: .leading, spacing: 8) {
                    if !ungroupedTasks.isEmpty {
                        FluxTaskSection(
                            title: "Tasks",
                            tasks: ungroupedTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            if task.isCompleted { task.reopen() } else { task.markComplete() }
                            try? modelContext.save()
                        }
                    }

                    FluxInlineTaskAdder(
                        project: project,
                        area: project.area,
                        heading: nil
                    )
                }

                // Add heading
                if showAddHeading {
                    HStack(spacing: 10) {
                        TextField("Heading name…", text: $newHeadingTitle)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .onSubmit { addHeading() }

                        Button("Add") { addHeading() }
                            .buttonStyle(.bordered)
                            .disabled(newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button { showAddHeading = false; newHeadingTitle = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                } else {
                    Button {
                        showAddHeading = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Heading")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(28)
        }
        .background(Color.clear)
    }

    private func addHeading() {
        let title = newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let heading = FluxHeading(
            title: title,
            sortOrder: Double(project.headingList.count),
            project: project
        )
        modelContext.insert(heading)
        try? modelContext.save()
        newHeadingTitle = ""
        showAddHeading = false
    }
}

// MARK: - Inline Task Adder

private struct FluxInlineTaskAdder: View {
    @Environment(\.modelContext) private var modelContext
    let project: FluxProject
    let area: FluxArea?
    let heading: FluxHeading?

    @State private var title = ""
    @State private var isActive = false

    var body: some View {
        if isActive {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                TextField("New task…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit { addTask() }
                    .onExitCommand {
                        isActive = false
                        title = ""
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        } else {
            Button {
                isActive = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("Add Task")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = FluxTask(
            title: trimmed,
            isInInbox: false,
            sortOrder: Double(project.taskList.count),
            area: area,
            project: project,
            heading: heading
        )
        modelContext.insert(task)
        try? modelContext.save()
        title = ""
    }
}

// MARK: - Header Card

private struct FluxHeaderCard: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

// MARK: - Project Card

private struct FluxProjectCard: View {
    let project: FluxProject

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                Text(project.goalSummary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(project.activeTaskCount) active")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Task Section

private struct FluxTaskSection: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let tasks: [FluxTask]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (FluxTask) -> Void

    private enum MoveDirection { case up, down }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tasks.count)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    VStack(spacing: 0) {
                        FluxTaskRow(
                            task: task,
                            isExpanded: expandedTaskID == task.id,
                            isCompleting: completingTaskIDs.contains(task.id),
                            onToggle: { onToggle(task) },
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    expandedTaskID = expandedTaskID == task.id ? nil : task.id
                                }
                            },
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if expandedTaskID == task.id { expandedTaskID = nil }
                                    completingTaskIDs.remove(task.id)
                                    modelContext.delete(task)
                                    try? modelContext.save()
                                }
                            }
                        )
                        .contextMenu {
                            if index > 0 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        moveTask(at: index, direction: .up)
                                    }
                                } label: {
                                    Label("Move Up", systemImage: "arrow.up")
                                }
                            }
                            if index < tasks.count - 1 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        moveTask(at: index, direction: .down)
                                    }
                                } label: {
                                    Label("Move Down", systemImage: "arrow.down")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if expandedTaskID == task.id { expandedTaskID = nil }
                                    completingTaskIDs.remove(task.id)
                                    modelContext.delete(task)
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if task.id != tasks.last?.id {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private func moveTask(at index: Int, direction: MoveDirection) {
        let targetIndex = direction == .up ? index - 1 : index + 1
        guard targetIndex >= 0 && targetIndex < tasks.count else { return }

        // Ensure unique sort orders
        for (i, t) in tasks.enumerated() {
            t.sortOrder = Double(i)
        }

        let a = tasks[index]
        let b = tasks[targetIndex]
        let temp = a.sortOrder
        a.sortOrder = b.sortOrder
        b.sortOrder = temp
        a.updatedAt = .now
        b.updatedAt = .now
        try? modelContext.save()
    }
}


// MARK: - Task Row

private enum TaskActionMode: Hashable {
    case calendar
    case tags
    case subtasks
    case deadline
}

private struct FluxTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    let task: FluxTask
    let isExpanded: Bool
    let isCompleting: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    var onDelete: (() -> Void)?

    @State private var activeAction: TaskActionMode?
    @State private var showTagsPopover = false
    @State private var showCalendarPopover = false
    @State private var showDeadlinePopover = false
    @State private var showMovePopover = false
    @State private var newSubtaskTitle = ""
    @State private var notesExpanded = false
    @State private var showDeadlineTime = false

    @Query(sort: \FluxArea.sortOrder) private var allAreas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var allProjects: [FluxProject]

    private var isDone: Bool { isCompleting || task.isCompleted }

    private var hasCompactMeta: Bool {
        task.project != nil || task.area != nil || !task.tagList.isEmpty
            || task.effectiveDate != nil || !task.checklistItems.isEmpty
            || task.recurrenceRule != nil || task.deadline != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row: checkbox + title
            HStack(alignment: hasCompactMeta && !isExpanded ? .top : .center, spacing: 14) {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)

                    // Collapsed inline meta
                    if !isExpanded && hasCompactMeta {
                        compactMeta
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .opacity(isCompleting ? 0.5 : 1.0)

            // Expanded
            if isExpanded {
                expandedContent
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }

            Divider()

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
    }

    // MARK: Collapsed meta badges

    private var compactMeta: some View {
        HStack(spacing: 6) {
            // 1. Area / Project
            if let project = task.project {
                FluxBadge(text: project.title, tint: project.tintHex)
            } else if let area = task.area {
                FluxBadge(text: area.title, tint: area.tintHex)
            }

            // 2. When date
            if let date = task.whenDate {
                FluxDateBadge(date: date, isDeadline: false)
            }

            // 3. Deadline
            if let deadline = task.deadline {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text(deadlineDisplayText(deadline))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: Capsule())
            }

            // 4. Tags
            ForEach(task.tagList.prefix(3)) { tag in
                FluxBadge(text: tag.title, tint: tag.tintHex)
            }

            // 5. Checklist
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
                .background(Color.black.opacity(0.06), in: Capsule())
            }
        }
    }

    // MARK: Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tag badges — directly under title
            if !task.tagList.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(task.tagList) { tag in
                        HStack(spacing: 4) {
                            Text(tag.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: tag.tintHex))
                            Button {
                                if let assignment = task.tagAssignmentList.first(where: { $0.tag?.id == tag.id }) {
                                    modelContext.delete(assignment)
                                }
                                task.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: tag.tintHex).opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: tag.tintHex).opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 56)
                .padding(.top, 2)
                .padding(.bottom, 10)
            }

            // Notes
            VStack(alignment: .leading, spacing: 2) {
                TextField("Notes", text: Binding(
                    get: { task.notes },
                    set: {
                        task.notes = $0
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(notesExpanded ? nil : 5)

                if task.notes.count > 100 && !notesExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            notesExpanded = true
                        }
                    } label: {
                        Text("Show more")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else if notesExpanded && task.notes.count > 100 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            notesExpanded = false
                        }
                    } label: {
                        Text("Show less")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 56)

            // Subtasks section
            if !task.checklistItems.isEmpty || activeAction == .subtasks {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtasks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 56)
                        .padding(.top, 14)

                    if !task.checklistItems.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                                FluxChecklistRow(item: item)
                            }
                        }
                        .padding(.horizontal, 38)
                    }

                    // Add subtask inline
                    if activeAction == .subtasks {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)

                            TextField("Add subtask…", text: $newSubtaskTitle)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(.horizontal, 56)
                        .padding(.top, 2)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 4)
            }

            // Bottom bar: breadcrumb on left, action buttons on right
            HStack(spacing: 0) {
                // Left: breadcrumb
                if let area = task.area {
                    HStack(spacing: 5) {
                        Image(systemName: area.symbolName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: area.tintHex))
                        Text(area.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: area.tintHex))

                        if let project = task.project {
                            Text("›")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                            Text(project.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Date / evening badge + deadline
                HStack(spacing: 8) {
                    dateLabel

                    if let deadline = task.deadline {
                        HStack(spacing: 3) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                            Text(deadlineDisplayText(deadline))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                    }
                }
                .font(.caption.weight(.medium))

                Spacer()
                    .frame(maxWidth: 16)

                // Right: action buttons
                HStack(spacing: 2) {
                    // Calendar popover
                    Button {
                        showCalendarPopover.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(showCalendarPopover ? .primary : (task.whenDate != nil ? .primary : .secondary))
                            .frame(width: 30, height: 28)
                            .background(showCalendarPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCalendarPopover, arrowEdge: .bottom) {
                        calendarPanel
                            .frame(width: 300)
                            .padding(4)
                    }

                    // Tags popover
                    Button {
                        showTagsPopover.toggle()
                    } label: {
                        Image(systemName: !task.tagList.isEmpty ? "tag.fill" : "tag")
                            .font(.system(size: 14))
                            .foregroundStyle(showTagsPopover ? .primary : (!task.tagList.isEmpty ? .primary : .secondary))
                            .frame(width: 30, height: 28)
                            .background(showTagsPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTagsPopover, arrowEdge: .bottom) {
                        FluxTagPanel(task: task)
                            .frame(width: 220)
                            .padding(4)
                    }

                    // Subtasks toggle (inline)
                    actionButton(.subtasks, icon: "checklist", filledIcon: "checklist.checked", active: !task.checklistItems.isEmpty)

                    // Deadline popover
                    Button {
                        showDeadlinePopover.toggle()
                    } label: {
                        Image(systemName: task.deadline != nil ? "flag.fill" : "flag")
                            .font(.system(size: 14))
                            .foregroundStyle(showDeadlinePopover ? Color.primary : (task.deadline != nil ? Color.orange : Color.secondary))
                            .frame(width: 30, height: 28)
                            .background(showDeadlinePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeadlinePopover, arrowEdge: .bottom) {
                        deadlinePanel
                            .frame(width: 300)
                            .padding(4)
                    }

                    // Move to popover
                    Button {
                        showMovePopover.toggle()
                    } label: {
                        Image(systemName: "arrow.turn.right.up")
                            .font(.system(size: 14))
                            .foregroundStyle(showMovePopover ? .primary : .secondary)
                            .frame(width: 30, height: 28)
                            .background(showMovePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMovePopover, arrowEdge: .bottom) {
                        movePanel
                            .frame(width: 260)
                            .padding(4)
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dateLabel: some View {
        if let date = task.whenDate {
            if task.isEvening {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo)
                    Text("This Evening")
                        .foregroundStyle(.indigo)
                }
            } else if Calendar.current.isDateInToday(date) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text("Today")
                        .foregroundStyle(.primary)
                }
            } else {
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .foregroundStyle(.secondary)
            }
        } else if task.isEvening {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.indigo)
                Text("This Evening")
                    .foregroundStyle(.indigo)
            }
        } else if task.status == .someday {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                Text("Later")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("")
        }
    }

    private func deadlineDisplayText(_ deadline: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: deadline)
        let minute = cal.component(.minute, from: deadline)
        let dateStr = deadline.formatted(.dateTime.month(.abbreviated).day())
        if hour == 0 && minute == 0 {
            return dateStr
        }
        let timeStr = deadline.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
        return "\(dateStr) \(timeStr)"
    }

    private func actionButton(_ mode: TaskActionMode, icon: String, filledIcon: String, active: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeAction = activeAction == mode ? nil : mode
            }
        } label: {
            Image(systemName: active ? filledIcon : icon)
                .font(.system(size: 14))
                .foregroundStyle(activeAction == mode ? .primary : (active ? .primary : .secondary))
                .frame(width: 30, height: 28)
                .background(activeAction == mode ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: Action panels

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick-pick buttons
            HStack(spacing: 8) {
                let isToday = task.whenDate != nil && Calendar.current.isDateInToday(task.whenDate!) && !task.isEvening
                let isEvening = task.isEvening
                let isLater = task.status == .someday && task.whenDate == nil

                calendarQuickButton(icon: "star.fill", iconColor: .yellow, label: "Today", isSelected: isToday) {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = false
                    task.status = .active
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                calendarQuickButton(icon: "moon.fill", iconColor: .indigo, label: "Evening", isSelected: isEvening) {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = true
                    task.status = .active
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                calendarQuickButton(icon: "moon.zzz.fill", iconColor: .secondary, label: "Later", isSelected: isLater) {
                    task.status = .someday
                    task.whenDate = nil
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                if task.whenDate != nil || isLater {
                    calendarQuickButton(icon: "xmark", iconColor: .secondary, label: "Clear") {
                        task.whenDate = nil
                        task.isEvening = false
                        task.status = .active
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
            }

            // Calendar grid
            FluxCalendarGrid(
                selectedDate: task.whenDate,
                onSelect: { date in
                    task.whenDate = date
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            )
        }
        .frame(minWidth: 280)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func calendarQuickButton(icon: String, iconColor: Color, label: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? iconColor : iconColor)
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 64, height: 48)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("Deadline")
                    .font(.subheadline.weight(.medium))

                Spacer()

                if task.deadline != nil {
                    Button {
                        task.deadline = nil
                        showDeadlineTime = false
                        task.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            FluxCalendarGrid(
                selectedDate: task.deadline,
                accentColor: .orange,
                onSelect: { date in
                    if showDeadlineTime, let existing = task.deadline {
                        // Preserve the time from the existing deadline
                        let cal = Calendar.current
                        let timeComps = cal.dateComponents([.hour, .minute], from: existing)
                        var dateComps = cal.dateComponents([.year, .month, .day], from: date)
                        dateComps.hour = timeComps.hour
                        dateComps.minute = timeComps.minute
                        task.deadline = cal.date(from: dateComps) ?? date
                    } else {
                        task.deadline = date
                    }
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            )

            // Time toggle
            HStack(spacing: 8) {
                Button {
                    showDeadlineTime.toggle()
                    if showDeadlineTime {
                        let cal = Calendar.current
                        if task.deadline == nil {
                            // No deadline yet — set today at 9 AM
                            task.deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
                        } else {
                            let hour = cal.component(.hour, from: task.deadline!)
                            if hour == 0 {
                                task.deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: task.deadline!)
                            }
                        }
                        task.updatedAt = .now
                        try? modelContext.save()
                    } else if let deadline = task.deadline {
                        // Remove time — reset to midnight
                        let cal = Calendar.current
                        task.deadline = cal.startOfDay(for: deadline)
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(showDeadlineTime ? "Remove time" : "Add time")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(showDeadlineTime ? .orange : .secondary)
                }
                .buttonStyle(.plain)

                if showDeadlineTime, let deadline = task.deadline {
                    Spacer()

                    let cal = Calendar.current
                    let hour = cal.component(.hour, from: deadline)
                    let minute = cal.component(.minute, from: deadline)
                    let is12Hour = hour % 12 == 0 ? 12 : hour % 12

                    HStack(spacing: 0) {
                        // Hour
                        Menu {
                            ForEach(1...12, id: \.self) { h in
                                Button("\(h)") {
                                    let newHour = hour >= 12 ? (h % 12) + 12 : h % 12
                                    task.deadline = cal.date(bySettingHour: newHour, minute: minute, second: 0, of: deadline)
                                    task.updatedAt = .now
                                    try? modelContext.save()
                                }
                            }
                        } label: {
                            Text("\(is12Hour)")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        Text(":")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        // Minute
                        Menu {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                Button(String(format: "%02d", m)) {
                                    task.deadline = cal.date(bySettingHour: hour, minute: m, second: 0, of: deadline)
                                    task.updatedAt = .now
                                    try? modelContext.save()
                                }
                            }
                        } label: {
                            Text(String(format: "%02d", minute))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        // AM/PM
                        Menu {
                            Button("AM") {
                                if hour >= 12 {
                                    task.deadline = cal.date(bySettingHour: hour - 12, minute: minute, second: 0, of: deadline)
                                    task.updatedAt = .now
                                    try? modelContext.save()
                                }
                            }
                            Button("PM") {
                                if hour < 12 {
                                    task.deadline = cal.date(bySettingHour: hour + 12, minute: minute, second: 0, of: deadline)
                                    task.updatedAt = .now
                                    try? modelContext.save()
                                }
                            }
                        } label: {
                            Text(hour < 12 ? "AM" : "PM")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(minWidth: 280)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            if let deadline = task.deadline {
                let cal = Calendar.current
                let hour = cal.component(.hour, from: deadline)
                let minute = cal.component(.minute, from: deadline)
                showDeadlineTime = hour != 0 || minute != 0
            }
        }
    }

    private var movePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.right.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Move task")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }

            Button {
                moveToInbox()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.isInInbox ? "checkmark.circle.fill" : "tray")
                        .font(.system(size: 12))
                        .foregroundStyle(task.isInInbox ? .green : .secondary)
                    Text("Inbox")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(task.isInInbox ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if !allAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Areas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(allAreas) { area in
                                areaMoveRow(area)

                                let projectsInArea = allProjects.filter { $0.area?.id == area.id }
                                if !projectsInArea.isEmpty {
                                    ForEach(projectsInArea) { project in
                                        projectMoveRow(project, in: area)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
        .frame(minWidth: 240)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func areaMoveRow(_ area: FluxArea) -> some View {
        let isSelected = task.area?.id == area.id && task.project == nil

        return Button {
            moveToArea(area)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: area.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: area.tintHex))
                    .frame(width: 14)
                Text(area.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func projectMoveRow(_ project: FluxProject, in area: FluxArea) -> some View {
        let isSelected = task.project?.id == project.id

        return Button {
            moveToProject(project, in: area)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                Text(project.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.leading, 16)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func moveToInbox() {
        task.area = nil
        task.project = nil
        task.heading = nil
        task.isInInbox = true
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }

    private func moveToArea(_ area: FluxArea) {
        task.area = area
        task.project = nil
        task.heading = nil
        task.isInInbox = false
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }

    private func moveToProject(_ project: FluxProject, in area: FluxArea) {
        task.area = area
        task.project = project
        task.heading = nil
        task.isInInbox = false
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let item = FluxChecklistItem(
            title: title,
            sortOrder: Double(task.checklistItems.count),
            task: task
        )
        modelContext.insert(item)
        if task.checklist == nil {
            task.checklist = []
        }
        task.checklist?.append(item)
        try? modelContext.save()
        newSubtaskTitle = ""
    }
}

// MARK: - Tag Panel

private struct FluxTagPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FluxTag.title) private var allTags: [FluxTag]
    let task: FluxTask

    @State private var searchText = ""

    private var filteredTags: [FluxTag] {
        let unassigned = allTags.filter { tag in
            !task.tagList.contains(where: { $0.id == tag.id })
        }
        if searchText.isEmpty { return unassigned }
        return unassigned.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Tags", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit {
                        createTag()
                    }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !filteredTags.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTags.prefix(6)) { tag in
                        Button {
                            let assignment = FluxTaskTagAssignment(task: task, tag: tag)
                            modelContext.insert(assignment)
                            task.updatedAt = .now
                            try? modelContext.save()
                            searchText = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: tag.tintHex))
                                Text(tag.title)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func createTag() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = FluxTag(title: name, tintHex: FluxTag.nextColor(forIndex: allTags.count))
        modelContext.insert(tag)
        let assignment = FluxTaskTagAssignment(task: task, tag: tag)
        modelContext.insert(assignment)
        task.updatedAt = .now
        try? modelContext.save()
        searchText = ""
    }
}

// MARK: - Checklist Row

private struct FluxChecklistRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: FluxChecklistItem

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                item.isCompleted.toggle()
                try? modelContext.save()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(item.isCompleted ? Color.green : Color.gray.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))

                Text(item.title)
                    .font(.subheadline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Calendar Grid

struct FluxCalendarGrid: View {
    let selectedDate: Date?
    var accentColor: Color = .blue
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayOfWeekSymbols = Calendar.current.shortWeekdaySymbols

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInGrid: [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: sel)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Month header with navigation
            HStack {
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(dayOfWeekSymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(height: 20)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            onSelect(date)
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: isSelected(date) ? .semibold : .regular))
                                .foregroundStyle(isSelected(date) ? .white : (isToday(date) ? accentColor : .primary))
                                .frame(width: 32, height: 32)
                                .background {
                                    if isSelected(date) {
                                        Circle().fill(accentColor)
                                    } else if isToday(date) {
                                        Circle().fill(accentColor.opacity(0.1))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}


// MARK: - Badges

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
            .background(Color.black.opacity(isDeadline ? 0.10 : 0.06), in: Capsule())
    }
}

// MARK: - Event Strip

private struct FluxEventStrip: View {
    let events: [FluxCalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar")
                .font(.headline)

            ForEach(events) { event in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.medium))
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

// MARK: - Empty State

private struct FluxEmptyState: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing in \(title.lowercased()) right now.")
                .font(.title3.weight(.semibold))
            Text("Use Quick Entry to capture something new, or drag tasks in from another project or area.")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var tintHex = "#2E6BC6"

    private let tintOptions = ["#2E6BC6", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#5B83B7"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Project")
                .font(.title2.weight(.semibold))

            TextField("Project name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Goal or description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            Picker("Area", selection: $selectedAreaID) {
                Text("No area").tag(UUID?.none)
                ForEach(areas) { area in
                    Text(area.title).tag(Optional(area.id))
                }
            }

            HStack(spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                ForEach(tintOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if tintHex == hex {
                                Circle().stroke(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { tintHex = hex }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func createProject() {
        let area = areas.first(where: { $0.id == selectedAreaID })
        let project = FluxProject(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalSummary: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tintHex: tintHex,
            sortOrder: Double(areas.flatMap(\.projectList).count),
            area: area
        )
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - New Area Sheet

struct NewAreaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]

    @State private var title = ""
    @State private var notes = ""
    @State private var symbolName = "square.grid.2x2"
    @State private var tintHex = "#5B83B7"

    private let symbolOptions = [
        "square.grid.2x2", "briefcase.fill", "heart.fill",
        "house.fill", "graduationcap.fill", "figure.run",
        "dollarsign.circle.fill", "paintbrush.fill"
    ]
    private let tintOptions = ["#5B83B7", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#2E6BC6"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Area")
                .font(.title2.weight(.semibold))

            TextField("Area name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text("Icon")
                    .font(.subheadline.weight(.medium))
                ForEach(symbolOptions, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(symbolName == symbol ? Color(hex: tintHex) : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            symbolName == symbol
                                ? Color(hex: tintHex).opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .onTapGesture { symbolName = symbol }
                }
            }

            HStack(spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                ForEach(tintOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if tintHex == hex {
                                Circle().stroke(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { tintHex = hex }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createArea()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func createArea() {
        let area = FluxArea(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            tintHex: tintHex,
            sortOrder: Double(areas.count)
        )
        modelContext.insert(area)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fluxShowCompletedTasks") private var showCompleted = false
    @AppStorage("fluxDefaultView") private var defaultView = "inbox"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))

            VStack(spacing: 0) {
                HStack {
                    Text("Show completed tasks")
                        .font(.body)
                    Spacer()
                    Toggle("", isOn: $showCompleted)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 16)

                HStack {
                    Text("Default view")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $defaultView) {
                        Text("Inbox").tag("inbox")
                        Text("Today").tag("today")
                        Text("Upcoming").tag("upcoming")
                        Text("Open").tag("anytime")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}

// MARK: - Supporting Types

private struct SelectedProjectIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var selectedProjectID: UUID? {
        get { self[SelectedProjectIDKey.self] }
        set { self[SelectedProjectIDKey.self] = newValue }
    }
}

// MARK: - Flow Layout (for tag chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Quick Find Overlay

private struct FluxQuickFindOverlay: View {
    let areas: [FluxArea]
    let projects: [FluxProject]
    let tasks: [FluxTask]
    let onSelectSidebar: (FluxSidebarSelection) -> Void
    let onSelectTask: (FluxTask) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool
    @State private var selectedIndex = 0

    private struct QuickFindItem: Identifiable {
        let id: String
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String?
        let action: () -> Void
    }

    private var coreListItems: [QuickFindItem] {
        let lists: [(String, String, Color, FluxSidebarSelection)] = [
            ("Inbox", "tray.fill", .primary, .inbox),
            ("Today", "sun.max.fill", .yellow, .today),
            ("Upcoming", "calendar", .red, .upcoming),
            ("Open", "tray.2.fill", .blue, .anytime),
            ("Later", "moon.zzz.fill", .purple, .someday),
            ("Done", "checkmark.circle.fill", .green, .logbook),
        ]
        return lists.compactMap { (title, icon, color, sel) in
            guard query.isEmpty || title.localizedCaseInsensitiveContains(query) else { return nil }
            return QuickFindItem(id: "list-\(title)", icon: icon, iconColor: color, title: title, subtitle: nil) {
                onSelectSidebar(sel)
            }
        }
    }

    private var areaItems: [QuickFindItem] {
        let filtered = query.isEmpty ? areas : areas.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.map { area in
            QuickFindItem(id: "area-\(area.id)", icon: area.symbolName, iconColor: Color(hex: area.tintHex), title: area.title, subtitle: nil) {
                onSelectSidebar(.area(area.id))
            }
        }
    }

    private var projectItems: [QuickFindItem] {
        let filtered = query.isEmpty ? projects : projects.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.map { project in
            QuickFindItem(id: "project-\(project.id)", icon: "paperplane", iconColor: Color(hex: project.tintHex), title: project.title, subtitle: project.area?.title) {
                onSelectSidebar(.project(project.id))
            }
        }
    }

    private var taskItems: [QuickFindItem] {
        guard !query.isEmpty else { return [] }
        let filtered = tasks.filter { !$0.isCompleted && $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.prefix(8).map { task in
            QuickFindItem(id: "task-\(task.id)", icon: "circle", iconColor: .secondary, title: task.title, subtitle: task.project?.title ?? task.area?.title) {
                onSelectTask(task)
            }
        }
    }

    private var allItems: [QuickFindItem] {
        coreListItems + areaItems + projectItems + taskItems
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
                        .font(.system(size: 18))
                        .focused($isFocused)
                        .onSubmit {
                            if let item = allItems[safe: selectedIndex] {
                                item.action()
                            }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !coreListItems.isEmpty {
                            quickFindSection("Lists", items: coreListItems)
                        }
                        if !areaItems.isEmpty {
                            quickFindSection("Areas", items: areaItems)
                        }
                        if !projectItems.isEmpty {
                            quickFindSection("Projects", items: projectItems)
                        }
                        if !taskItems.isEmpty {
                            quickFindSection("Tasks", items: taskItems)
                        }
                        if allItems.isEmpty {
                            Text("No results")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(16)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 340)
            }
            .frame(width: 420)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            .padding(.bottom, 100)
        }
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, allItems.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
    }

    private func quickFindSection(_ title: String, items: [QuickFindItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let globalIndex = globalIndex(for: item)
                Button {
                    item.action()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.iconColor)
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
                    .padding(.vertical, 7)
                    .background(
                        globalIndex == selectedIndex
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func globalIndex(for item: QuickFindItem) -> Int {
        allItems.firstIndex(where: { $0.id == item.id }) ?? -1
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}

import Foundation
import SwiftData

enum FluxSampleDataSeeder {
    @MainActor
    static func bootstrapIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<FluxArea>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let work = FluxArea(title: "Work", notes: "Professional commitments and shipping work.", symbolName: "briefcase.fill", tintHex: "#62666D", sortOrder: 0)
        let health = FluxArea(title: "Health", notes: "Body, energy, appointments, and routines.", symbolName: "heart.fill", tintHex: "#FF383C", sortOrder: 1)
        let personal = FluxArea(title: "Personal", notes: "Life admin and personal projects.", symbolName: "house.fill", tintHex: "#8A7D6A", sortOrder: 2)

        let keynote = FluxProject(
            title: "Prepare Presentation",
            notes: """
            ## Keep it concise
            Focus on the three takeaways the audience should remember.
            """,
            goalSummary: "Land the story, tighten the slides, and rehearse once cleanly.",
            tintHex: "#686C73",
            sortOrder: 0,
            area: work
        )
        let slides = FluxHeading(title: "Slides and notes", sortOrder: 0, project: keynote)
        let prep = FluxHeading(title: "Preparation", sortOrder: 1, project: keynote)
        let facilities = FluxHeading(title: "Facilities", sortOrder: 2, project: keynote)

        let important = FluxTag(title: "Important", symbolName: "exclamationmark.circle", tintHex: "#7A7068")
        let john = FluxTag(title: "John", symbolName: "person.fill", tintHex: "#8A8E95")
        let errands = FluxTag(title: "Errand", symbolName: "car.fill", tintHex: "#72767D")

        let task1 = FluxTask(
            title: "Revise introduction",
            notes: "Tighten the opening two slides and simplify the problem statement.",
            whenDate: .now,
            isInInbox: false,
            project: keynote,
            heading: slides
        )
        let task2 = FluxTask(
            title: "Review milestones from last quarter",
            notes: "Confirm the final metrics before presenting.",
            whenDate: .now,
            isInInbox: false,
            project: keynote,
            heading: slides
        )
        let task2Important = FluxTaskTagAssignment(task: task2, tag: important)
        let task3 = FluxTask(
            title: "Book the conference room",
            notes: "Reserve the room with screen sharing enabled.",
            whenDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            isInInbox: false,
            isEvening: true,
            project: keynote,
            heading: facilities
        )
        let task3Important = FluxTaskTagAssignment(task: task3, tag: important)
        let task4 = FluxTask(
            title: "Renew gym membership",
            notes: "Check if annual pricing is better than month-to-month.",
            status: .active,
            isInInbox: true
        )
        let task5 = FluxTask(
            title: "Research Japanese study plan",
            notes: "Maybe start with a light reading + listening routine.",
            status: .someday,
            isInInbox: false,
            area: personal
        )
        let task6 = FluxTask(
            title: "Schedule annual physical",
            notes: "Call the clinic and confirm fasting instructions.",
            whenDate: .now,
            isInInbox: false,
            area: health
        )
        let task6Errands = FluxTaskTagAssignment(task: task6, tag: errands)
        let task7 = FluxTask(
            title: "Share final deck with John",
            notes: "Send the PDF after QA and ask for one last pass.",
            whenDate: .now,
            status: .completed,
            isInInbox: false,
            project: keynote,
            heading: prep
        )
        task7.completedAt = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        let task7John = FluxTaskTagAssignment(task: task7, tag: john)

        let checklist1 = FluxChecklistItem(title: "Capture revised numbers", sortOrder: 0, task: task1)
        let checklist2 = FluxChecklistItem(title: "Shorten slide 2", isCompleted: true, sortOrder: 1, task: task1)
        task1.checklist = [checklist1, checklist2]

        context.insert(work)
        context.insert(health)
        context.insert(personal)
        context.insert(keynote)
        context.insert(slides)
        context.insert(prep)
        context.insert(facilities)
        context.insert(important)
        context.insert(john)
        context.insert(errands)
        context.insert(task2Important)
        context.insert(task3Important)
        context.insert(task6Errands)
        context.insert(task7John)
        context.insert(task1)
        context.insert(task2)
        context.insert(task3)
        context.insert(task4)
        context.insert(task5)
        context.insert(task6)
        context.insert(task7)

        try? context.save()
    }
}

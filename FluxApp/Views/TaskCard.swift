import SwiftData
import SwiftUI

struct TaskCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
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
                        TaskMeta(task: task)
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

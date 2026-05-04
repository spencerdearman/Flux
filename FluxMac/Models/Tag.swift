import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var title: String = ""
    var symbolName: String = "tag"
    var tintHex: String = "#8897AA"

    @Relationship(deleteRule: .cascade, inverse: \TaskTagAssignment.tag)
    var taskAssignments: [TaskTagAssignment]?

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

import Foundation
import SwiftData

enum SidebarSelection: Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case area(UUID)
    case project(UUID)
}

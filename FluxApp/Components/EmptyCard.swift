import SwiftData
import SwiftUI

struct EmptyCard: View {
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

import SwiftData
import SwiftUI

struct SectionCard<Content: View>: View {
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

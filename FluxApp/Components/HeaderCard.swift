import SwiftData
import SwiftUI

struct HeaderCard: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

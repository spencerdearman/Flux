import SwiftData
import SwiftUI

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white, Color(white: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

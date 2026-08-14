import SwiftUI

struct PlaceholderView: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer",
                               description: Text("模块建设中"))
    }
}

import Core
import SwiftUI

struct ContentView: View {
    private let model = CartModel()

    var body: some View {
        VStack(spacing: 8) {
            Text("Total: \(model.totalText)")
            Text(model.tierLabel)
        }
        .padding()
    }
}

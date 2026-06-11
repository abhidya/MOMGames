import SwiftUI

struct RootView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
                .padding(12)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.screen {
        case .picker:
            GamePickerView(controller: controller)
        case .game(let envelope):
            GameHostView(controller: controller, envelope: envelope)
        }
    }
}

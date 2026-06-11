import SwiftUI

/// Minimal container app. The real product is the iMessage extension; this host
/// just satisfies Apple's requirement that a Messages extension ship inside an
/// app and gives players a place to read how to start a game.
@main
struct MOMGamesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("MOM Games")
                .font(.largeTitle.bold())
            Text("Play turn-based games right inside Messages.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Open a conversation, tap the Apps button, and choose MOM Games to start a match. Each turn is sent as a message.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

import Messages
import SwiftUI
import UIKit

/// The iMessage extension entry point. Hosts the SwiftUI game UI and bridges the
/// Messages lifecycle into `GameController`.
final class MessagesViewController: MSMessagesAppViewController {
    private let controller = GameController()
    private var hosting: UIHostingController<RootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        controller.onSend = { [weak self] message in
            self?.insert(message)
        }
        controller.onRequestExpanded = { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }

        let host = UIHostingController(rootView: RootView(controller: controller))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hosting = host
    }

    // MARK: - Conversation lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        controller.isCompact = presentationStyle == .compact
        controller.update(with: conversation)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        controller.update(with: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        controller.isCompact = presentationStyle == .compact
    }

    // MARK: - Sending

    private func insert(_ message: MSMessage) {
        guard let conversation = activeConversation else { return }
        conversation.insert(message) { error in
            if let error { NSLog("MOMGames insert error: \(error.localizedDescription)") }
        }
        requestPresentationStyle(.compact)
    }
}

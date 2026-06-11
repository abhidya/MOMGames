import SwiftUI

/// Karachi Coup UI. Renders the public board, the local player's private hand,
/// and phase-specific controls (action menu, challenge/block prompts, burn and
/// exchange pickers, lobby, game over).
struct CoupView: View {
    @ObservedObject var controller: GameController
    let envelope: MatchEnvelope

    @State private var awaitingTargetFor: KarachiCoup.Action?
    @State private var exchangeSelection: Set<Int> = []

    private typealias Coup = KarachiCoup

    private var state: Coup.State {
        envelope.state.decoded(Coup.State.self, fallback: Coup.lobbyState(playerCount: envelope.maxPlayers))
    }

    private var mySeat: Int? { envelope.seatedIndex(of: controller.localParticipantID) }
    private var active: Bool { controller.canAct(in: envelope) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let line = state.log.last {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if state.phase == .lobby {
                lobby
            } else {
                scoreboard
                controls
            }
        }
    }

    // MARK: - Lobby

    private var lobby: some View {
        VStack(spacing: 12) {
            Text("\(envelope.players.count)/\(envelope.maxPlayers) players in")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if mySeat == nil, active {
                primaryButton("Join game", icon: "person.badge.plus") { join() }
            } else {
                Text(mySeat == nil ? "This match is full." : "Waiting for everyone to join…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Scoreboard

    private var scoreboard: some View {
        VStack(spacing: 6) {
            ForEach(0..<state.playerCount, id: \.self) { seat in
                seatRow(seat)
            }
        }
    }

    private func seatRow(_ seat: Int) -> some View {
        let alive = Coup.isAlive(state, seat)
        let isMe = seat == mySeat
        let isActive = Coup.activeSeat(state) == seat
        return HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Theme.accent : Theme.textSecondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text("P\(seat + 1)\(isMe ? " (you)" : "")")
                .font(.subheadline.weight(isActive ? .bold : .regular))
                .foregroundStyle(alive ? Theme.textPrimary : Theme.textSecondary)
                .strikethrough(!alive)
            Spacer()
            Text("🪙\(state.coins.indices.contains(seat) ? state.coins[seat] : 0)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            cardRow(seat: seat, isMe: isMe)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func cardRow(seat: Int, isMe: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(Coup.revealedRoles(state, seat).enumerated()), id: \.offset) { _, role in
                cardChip(role.title, revealed: true)
            }
            if isMe {
                // Only the local player sees their hidden Connections.
                ForEach(Array(Coup.hiddenRoles(state, seat).enumerated()), id: \.offset) { _, role in
                    cardChip(role.title, revealed: false)
                }
            } else {
                ForEach(0..<Coup.influence(state, seat), id: \.self) { _ in
                    cardChip("●", revealed: false)
                }
            }
        }
    }

    private func cardChip(_ text: String, revealed: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(revealed ? Theme.textSecondary : Theme.textPrimary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(revealed ? Theme.background : Theme.accent.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 5))
            .strikethrough(revealed)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch state.phase {
        case .gameOver:
            gameOver
        case .action where active:
            actionControls
        case .response where active:
            responseControls
        case .blockResponse where active:
            blockResponseControls
        case .burn where active:
            burnControls
        case .exchange where active:
            exchangeControls
        default:
            Text(waitingText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var waitingText: String {
        let seat = Coup.activeSeat(state)
        return seat >= 0 ? "Waiting for Player \(seat + 1)…" : "Waiting…"
    }

    private var actionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let action = awaitingTargetFor {
                Text("Choose a target for \(action.title)")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                FlowButtons(items: targets.map { "Player \($0 + 1)" }) { index in
                    declare(action, target: targets[index])
                    awaitingTargetFor = nil
                }
                Button("Cancel") { awaitingTargetFor = nil }
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Your move").font(.caption).foregroundStyle(Theme.textSecondary)
                let actions = Coup.availableActions(state, seat: mySeat ?? state.turnActor)
                FlowButtons(items: actions.map(\.title)) { index in
                    let action = actions[index]
                    if action.needsTarget {
                        awaitingTargetFor = action
                    } else {
                        declare(action, target: nil)
                    }
                }
            }
        }
    }

    private var responseControls: some View {
        let pending = state.pending
        return VStack(alignment: .leading, spacing: 8) {
            if let pending {
                Text("Player \(pending.actor + 1) claims \(pending.action.claimedRole?.title ?? pending.action.title).")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                if Coup.canChallengeResponse(state) {
                    actionButton("Call Bakwaas", tint: Theme.danger) {
                        let (s, c) = Coup.challengeAction(state); commit(s, caption: c)
                    }
                }
                actionButton("Let It Slide", tint: Theme.textSecondary) {
                    let (s, c) = Coup.passResponse(state); commit(s, caption: c)
                }
            }
            let blocks = Coup.blockOptions(state)
            if !blocks.isEmpty {
                FlowButtons(items: blocks.map { "Block: \($0.title)" }) { index in
                    let (s, c) = Coup.blockAction(state, role: blocks[index]); commit(s, caption: c)
                }
            }
        }
    }

    private var blockResponseControls: some View {
        let pending = state.pending
        return VStack(alignment: .leading, spacing: 8) {
            if let pending, let blocker = pending.blocker, let role = pending.blockRole {
                Text("Player \(blocker + 1) blocks with \(role.title).")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                actionButton("Call Bakwaas", tint: Theme.danger) {
                    let (s, c) = Coup.challengeBlock(state); commit(s, caption: c)
                }
                actionButton("Let It Slide", tint: Theme.textSecondary) {
                    let (s, c) = Coup.passBlockResponse(state); commit(s, caption: c)
                }
            }
        }
    }

    private var burnControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Burn a Connection").font(.caption).foregroundStyle(Theme.textSecondary)
            let seat = state.burnSeat ?? mySeat ?? 0
            let cards = Array(state.hands[seat].enumerated()).filter { !$0.element.revealed }
            FlowButtons(items: cards.map { $0.element.role.title }) { listIndex in
                let cardIndex = cards[listIndex].offset
                let s = Coup.burn(state, cardIndex: cardIndex)
                commit(s, caption: "Player \(seat + 1) burns a Connection")
            }
        }
    }

    private var exchangeControls: some View {
        let pool = state.exchange?.pool ?? []
        let keep = state.exchange?.keep ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Keep \(keep) Connection\(keep == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            FlowButtons(items: pool.enumerated().map { idx, role in
                exchangeSelection.contains(idx) ? "✓ \(role.title)" : role.title
            }) { index in
                if exchangeSelection.contains(index) {
                    exchangeSelection.remove(index)
                } else if exchangeSelection.count < keep {
                    exchangeSelection.insert(index)
                }
            }
            primaryButton("Confirm", icon: "checkmark") {
                let s = Coup.resolveExchange(state, keepIndices: Array(exchangeSelection))
                exchangeSelection = []
                commit(s, caption: "Player \(state.turnActor + 1) swapped Connections")
            }
            .disabled(exchangeSelection.count != keep)
        }
    }

    private var gameOver: some View {
        let seat = state.winnerSeat
        let won = seat == mySeat
        return VStack(spacing: 10) {
            Text(won ? "You win! 🎉" : "Player \((seat ?? 0) + 1) wins")
                .font(.headline)
                .foregroundStyle(won ? Theme.positive : Theme.danger)
            primaryButton("Rematch", icon: "arrow.clockwise") {
                controller.rematch(from: envelope)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var targets: [Int] {
        (0..<state.playerCount).filter { $0 != mySeat && Coup.isAlive(state, $0) }
    }

    private func declare(_ action: KarachiCoup.Action, target: Int?) {
        let (s, c) = Coup.declare(state, action: action, target: target)
        commit(s, caption: c)
    }

    private func join() {
        let seated = envelope.players.count
        let (newState, dealt, caption) = Coup.join(currentSeated: seated, playerCount: envelope.maxPlayers)
        let next = dealt ? 0 : seated + 1
        let result = MoveResult(state: newState.jsonData(), caption: caption, subcaption: "",
                                finished: false, winnerSeat: nil, nextTurnSeat: next)
        controller.commit(result, in: envelope)
    }

    private func commit(_ newState: KarachiCoup.State, caption: String) {
        let finished = newState.phase == .gameOver
        let nextSeat = Coup.activeSeat(newState)
        let result = MoveResult(
            state: newState.jsonData(),
            caption: caption,
            subcaption: finished ? "" : "Tap to take your turn",
            finished: finished,
            winnerSeat: newState.winnerSeat,
            nextTurnSeat: finished ? nil : (nextSeat >= 0 ? nextSeat : nil)
        )
        controller.commit(result, in: envelope)
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(tint.opacity(0.2), in: Capsule())
                .foregroundStyle(tint == Theme.textSecondary ? Theme.textPrimary : tint)
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
    }
}

/// A simple wrapping row of small buttons used for action/card choices.
private struct FlowButtons: View {
    let items: [String]
    let onTap: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                Button { onTap(index) } label: {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

import Foundation

/// Karachi Coup — a Karachi-themed implementation of Coup (a hidden-role
/// bluffing game) for 2–6 players. Pure rules engine; the view drives it.
///
/// Architecture notes for the serverless iMessage model:
/// - Challenge/block windows are *serialized*: responders are polled one at a
///   time in seat order, so there is always exactly one active seat and no
///   concurrent-insert forks.
/// - Cards are stored in the (publicly decodable) payload in plaintext — the UI
///   only reveals the local player's hidden Connections (the honor-system
///   secrecy chosen for this build).
/// - The first challenge concludes the challenge window (a survived claim is
///   replaced and re-drawn, so re-challenging is pointless); a block may be
///   challenged once. These keep the async flow bounded while staying faithful.
enum KarachiCoup {

    // MARK: - Roles & cards

    enum Role: String, Codable, CaseIterable {
        case maliksaab, policewala, bhai, zardaar, mumma

        var title: String {
            switch self {
            case .maliksaab: return "Malik Saab"
            case .policewala: return "Police Wala"
            case .bhai: return "Bhai"
            case .zardaar: return "Zardaar Chor"
            case .mumma: return "Mumma"
            }
        }
    }

    struct Card: Codable, Equatable {
        var role: Role
        /// A revealed card is a lost (public) Connection.
        var revealed: Bool
    }

    // MARK: - Actions

    enum Action: String, Codable, CaseIterable {
        case chai, rishtedaar, kiraya, raid, bhai, zardaar, beizzati

        var title: String {
            switch self {
            case .chai: return "Chai Paisa"
            case .rishtedaar: return "Rishtedaar Help"
            case .kiraya: return "Kiraya Collection"
            case .raid: return "Police Wala Raid"
            case .bhai: return "Bhai Ka Scene"
            case .zardaar: return "Zardaar Jugaad"
            case .beizzati: return "Full Beizzati"
            }
        }

        var cost: Int {
            switch self {
            case .bhai: return 3
            case .beizzati: return 7
            default: return 0
            }
        }

        var claimedRole: Role? {
            switch self {
            case .kiraya: return .maliksaab
            case .raid: return .policewala
            case .bhai: return .bhai
            case .zardaar: return .zardaar
            default: return nil
            }
        }

        var challengeable: Bool { claimedRole != nil }

        var needsTarget: Bool {
            self == .raid || self == .bhai || self == .beizzati
        }

        /// Roles that can block this action (empty = unblockable).
        var blockRoles: [Role] {
            switch self {
            case .rishtedaar: return [.maliksaab]
            case .raid: return [.policewala, .zardaar]
            case .bhai: return [.mumma]
            default: return []
            }
        }

        var blockable: Bool { !blockRoles.isEmpty }

        /// Only the target may block raid/bhai; anyone may block foreign aid.
        var blockableByTargetOnly: Bool { self == .raid || self == .bhai }
    }

    // MARK: - State

    enum Phase: String, Codable {
        case lobby
        case action          // turnActor chooses an action
        case response        // serialized challenge/block window
        case blockResponse   // serialized challenge-the-block window
        case burn            // burnSeat reveals a Connection
        case exchange        // turnActor keeps cards after Zardaar Jugaad
        case gameOver
    }

    enum Resume: String, Codable {
        case afterEffectEndTurn   // a burn that was the action's effect
        case actionFailed         // actor lost a challenge; action is void
        case challengerBurned     // actor defended; proceed (block, then effect)
        case blockStands          // block survived a challenge; action void
        case blockFailedProceed   // block lost a challenge; action proceeds
    }

    struct Pending: Codable {
        var action: Action
        var actor: Int
        var target: Int? = nil
        var responderQueue: [Int]
        var blocker: Int? = nil
        var blockRole: Role? = nil
        /// Set once a challenge has been spent so only blocks remain offered.
        var challengeSpent: Bool = false
    }

    struct Exchange: Codable {
        var pool: [Role]
        var keep: Int
    }

    struct State: Codable {
        var phase: Phase
        var playerCount: Int
        var coins: [Int]
        var hands: [[Card]]
        var deck: [Role]
        var turnActor: Int
        var pending: Pending?
        var burnSeat: Int?
        var burnResume: Resume?
        var exchange: Exchange?
        var log: [String]
        var winnerSeat: Int?
    }

    // MARK: - Setup

    static func lobbyState(playerCount: Int) -> State {
        State(phase: .lobby, playerCount: playerCount, coins: [], hands: [], deck: [],
              turnActor: 0, pending: nil, burnSeat: nil, burnResume: nil, exchange: nil,
              log: ["Waiting for players to join…"], winnerSeat: nil)
    }

    static func deal(playerCount: Int) -> State {
        var deck: [Role] = []
        for role in Role.allCases { deck.append(contentsOf: Array(repeating: role, count: 3)) }
        deck.shuffle()

        var hands: [[Card]] = []
        for _ in 0..<playerCount {
            var hand: [Card] = []
            for _ in 0..<2 where !deck.isEmpty {
                hand.append(Card(role: deck.removeLast(), revealed: false))
            }
            hands.append(hand)
        }
        return State(phase: .action, playerCount: playerCount,
                     coins: Array(repeating: 2, count: playerCount),
                     hands: hands, deck: deck, turnActor: 0, pending: nil,
                     burnSeat: nil, burnResume: nil, exchange: nil,
                     log: ["Cards dealt. Player 1 to act."], winnerSeat: nil)
    }

    // MARK: - Derived helpers

    static func influence(_ s: State, _ seat: Int) -> Int {
        guard s.hands.indices.contains(seat) else { return 0 }
        return s.hands[seat].filter { !$0.revealed }.count
    }

    static func isAlive(_ s: State, _ seat: Int) -> Bool { influence(s, seat) > 0 }

    static func livingSeats(_ s: State) -> [Int] {
        (0..<s.playerCount).filter { isAlive(s, $0) }
    }

    static func hasRole(_ s: State, _ seat: Int, _ role: Role) -> Bool {
        guard s.hands.indices.contains(seat) else { return false }
        return s.hands[seat].contains { !$0.revealed && $0.role == role }
    }

    static func hiddenRoles(_ s: State, _ seat: Int) -> [Role] {
        guard s.hands.indices.contains(seat) else { return [] }
        return s.hands[seat].filter { !$0.revealed }.map(\.role)
    }

    static func revealedRoles(_ s: State, _ seat: Int) -> [Role] {
        guard s.hands.indices.contains(seat) else { return [] }
        return s.hands[seat].filter(\.revealed).map(\.role)
    }

    /// The single seat whose input the current phase is waiting on.
    static func activeSeat(_ s: State) -> Int {
        switch s.phase {
        case .lobby, .gameOver: return -1
        case .action, .exchange: return s.turnActor
        case .response, .blockResponse: return s.pending?.responderQueue.first ?? s.turnActor
        case .burn: return s.burnSeat ?? s.turnActor
        }
    }

    private static func nextLivingSeat(after seat: Int, _ s: State) -> Int {
        guard !livingSeats(s).isEmpty else { return seat }
        var next = (seat + 1) % s.playerCount
        var guardCount = 0
        while !isAlive(s, next), guardCount < s.playerCount {
            next = (next + 1) % s.playerCount
            guardCount += 1
        }
        return next
    }

    private static func responderOrder(after actor: Int, _ s: State) -> [Int] {
        var order: [Int] = []
        for offset in 1..<s.playerCount {
            let seat = (actor + offset) % s.playerCount
            if isAlive(s, seat) { order.append(seat) }
        }
        return order
    }

    private static func replaceRole(_ s: inout State, seat: Int, role: Role) {
        guard let index = s.hands[seat].firstIndex(where: { !$0.revealed && $0.role == role }) else { return }
        s.deck.append(role)
        s.deck.shuffle()
        if let drawn = s.deck.popLast() {
            s.hands[seat][index] = Card(role: drawn, revealed: false)
        }
    }

    // MARK: - Lobby

    /// Result of a player joining the lobby: the next state, whether the roster
    /// just filled (cards dealt), and a caption.
    static func join(currentSeated: Int, playerCount: Int) -> (state: State, dealt: Bool, caption: String) {
        let seatedAfter = currentSeated + 1
        if seatedAfter >= playerCount {
            return (deal(playerCount: playerCount), true, "All players in — cards dealt!")
        }
        var s = lobbyState(playerCount: playerCount)
        s.log = ["Player \(seatedAfter) joined (\(seatedAfter)/\(playerCount)). Waiting…"]
        return (s, false, "Player \(seatedAfter) joined (\(seatedAfter)/\(playerCount))")
    }

    // MARK: - Action declaration

    static func declare(_ state: State, action: Action, target: Int?) -> (State, String) {
        var s = state
        let actor = s.turnActor
        s.coins[actor] -= action.cost
        var pending = Pending(action: action, actor: actor, target: target, responderQueue: [])
        s.pending = pending

        let targetText = target.map { " on Player \($0 + 1)" } ?? ""
        let caption = "Player \(actor + 1): \(action.title)\(targetText)"

        if !action.challengeable && !action.blockable {
            // Chai Paisa / Full Beizzati resolve immediately.
            return (resolveEffect(s), caption)
        }
        pending.responderQueue = responderOrder(after: actor, s)
        s.pending = pending
        s.phase = .response
        return (s, caption)
    }

    // MARK: - Response window (challenge / block)

    static func challengeAction(_ state: State) -> (State, String) {
        var s = state
        guard let pending = s.pending, let claimed = pending.action.claimedRole else { return (s, "") }
        let challenger = activeSeat(s)
        let actor = pending.actor

        if hasRole(s, actor, claimed) {
            replaceRole(&s, seat: actor, role: claimed)
            var p = pending
            p.challengeSpent = true
            s.pending = p
            return (enterBurn(s, seat: challenger, resume: .challengerBurned),
                    "Player \(challenger + 1) called bakwaas — Player \(actor + 1) had \(claimed.title)!")
        } else {
            return (enterBurn(s, seat: actor, resume: .actionFailed),
                    "Player \(actor + 1) was bluffing \(claimed.title) — caught!")
        }
    }

    static func blockAction(_ state: State, role: Role) -> (State, String) {
        var s = state
        guard var pending = s.pending else { return (s, "") }
        let blocker = activeSeat(s)
        pending.blocker = blocker
        pending.blockRole = role
        pending.responderQueue = responderOrder(after: blocker, s)
        s.pending = pending
        s.phase = .blockResponse
        return (s, "Player \(blocker + 1) uses setting (\(role.title)) to block")
    }

    static func passResponse(_ state: State) -> (State, String) {
        var s = state
        guard var pending = s.pending else { return (s, "") }
        if !pending.responderQueue.isEmpty { pending.responderQueue.removeFirst() }
        s.pending = pending
        if pending.responderQueue.isEmpty {
            // Everyone let it slide — the action succeeds.
            return (resolveEffect(s), "No objections — \(pending.action.title) succeeds")
        }
        return (s, "Let it slide")
    }

    // MARK: - Block response window

    static func challengeBlock(_ state: State) -> (State, String) {
        var s = state
        guard let pending = s.pending, let blocker = pending.blocker, let blockRole = pending.blockRole else { return (s, "") }
        let challenger = activeSeat(s)

        if hasRole(s, blocker, blockRole) {
            replaceRole(&s, seat: blocker, role: blockRole)
            return (enterBurn(s, seat: challenger, resume: .blockStands),
                    "Player \(challenger + 1) called bakwaas — Player \(blocker + 1) had \(blockRole.title)!")
        } else {
            return (enterBurn(s, seat: blocker, resume: .blockFailedProceed),
                    "Player \(blocker + 1) bluffed the block — caught!")
        }
    }

    static func passBlockResponse(_ state: State) -> (State, String) {
        var s = state
        guard var pending = s.pending else { return (s, "") }
        if !pending.responderQueue.isEmpty { pending.responderQueue.removeFirst() }
        s.pending = pending
        if pending.responderQueue.isEmpty {
            // Block stands; the action is voided.
            return (endTurn(s), "Block holds — \(pending.action.title) is stopped")
        }
        return (s, "Let it slide")
    }

    // MARK: - Burning a Connection

    private static func enterBurn(_ state: State, seat: Int, resume: Resume) -> State {
        var s = state
        s.phase = .burn
        s.burnSeat = seat
        s.burnResume = resume
        // Auto-burn when only one Connection remains.
        if influence(s, seat) <= 1, let index = s.hands[seat].firstIndex(where: { !$0.revealed }) {
            return burn(s, cardIndex: index)
        }
        return s
    }

    static func burn(_ state: State, cardIndex: Int) -> State {
        var s = state
        guard let seat = s.burnSeat, s.hands[seat].indices.contains(cardIndex) else { return s }
        s.hands[seat][cardIndex].revealed = true
        let role = s.hands[seat][cardIndex].role
        s.log.append("Player \(seat + 1) burns \(role.title).")
        if influence(s, seat) == 0 {
            s.log.append("Player \(seat + 1) is out!")
        }

        let resume = s.burnResume
        s.burnSeat = nil
        s.burnResume = nil

        if livingSeats(s).count <= 1 {
            s.phase = .gameOver
            s.winnerSeat = livingSeats(s).first
            return s
        }

        switch resume {
        case .afterEffectEndTurn, .actionFailed, .blockStands, nil:
            return endTurn(s)
        case .challengerBurned:
            return proceedAfterSurvivedChallenge(s)
        case .blockFailedProceed:
            return resolveEffect(s)
        }
    }

    /// After the actor survives a challenge, the action proceeds — but a
    /// blockable action may still be blocked by an eligible defender.
    private static func proceedAfterSurvivedChallenge(_ state: State) -> State {
        var s = state
        guard let pending = s.pending else { return endTurn(s) }
        if pending.action.blockable {
            let eligible = blockEligibleSeats(s, pending: pending)
            if !eligible.isEmpty {
                var p = pending
                p.responderQueue = eligible
                s.pending = p
                s.phase = .response
                return s
            }
        }
        return resolveEffect(s)
    }

    private static func blockEligibleSeats(_ s: State, pending: Pending) -> [Int] {
        if pending.action.blockableByTargetOnly {
            if let target = pending.target, isAlive(s, target) { return [target] }
            return []
        }
        // Foreign aid: any living non-actor may block.
        return responderOrder(after: pending.actor, s)
    }

    // MARK: - Effect resolution

    private static func resolveEffect(_ state: State) -> State {
        var s = state
        guard let pending = s.pending else { return endTurn(s) }
        let actor = pending.actor
        switch pending.action {
        case .chai:
            s.coins[actor] += 1
            return endTurn(s)
        case .rishtedaar:
            s.coins[actor] += 2
            return endTurn(s)
        case .kiraya:
            s.coins[actor] += 3
            return endTurn(s)
        case .raid:
            if let target = pending.target {
                let amount = min(2, s.coins[target])
                s.coins[target] -= amount
                s.coins[actor] += amount
            }
            return endTurn(s)
        case .bhai:
            if let target = pending.target, isAlive(s, target) {
                return enterBurn(s, seat: target, resume: .afterEffectEndTurn)
            }
            return endTurn(s)
        case .beizzati:
            if let target = pending.target, isAlive(s, target) {
                return enterBurn(s, seat: target, resume: .afterEffectEndTurn)
            }
            return endTurn(s)
        case .zardaar:
            return enterExchange(s)
        }
    }

    // MARK: - Exchange (Zardaar Jugaad)

    private static func enterExchange(_ state: State) -> State {
        var s = state
        let actor = s.turnActor
        var pool = hiddenRoles(s, actor)
        let keep = pool.count
        for _ in 0..<2 where !s.deck.isEmpty {
            pool.append(s.deck.removeLast())
        }
        s.exchange = Exchange(pool: pool, keep: keep)
        s.phase = .exchange
        return s
    }

    static func resolveExchange(_ state: State, keepIndices: [Int]) -> State {
        var s = state
        guard let exchange = s.exchange else { return endTurn(s) }
        let actor = s.turnActor
        let kept = keepIndices.compactMap { exchange.pool.indices.contains($0) ? exchange.pool[$0] : nil }
        let keep = Array(kept.prefix(exchange.keep))

        // Returned roles go back to the deck.
        var remaining = exchange.pool
        for role in keep {
            if let idx = remaining.firstIndex(of: role) { remaining.remove(at: idx) }
        }
        s.deck.append(contentsOf: remaining)
        s.deck.shuffle()

        // Rebuild the actor's hand: keep revealed cards, replace hidden ones.
        let revealed = s.hands[actor].filter(\.revealed)
        s.hands[actor] = revealed + keep.map { Card(role: $0, revealed: false) }
        s.exchange = nil
        s.log.append("Player \(actor + 1) swapped Connections.")
        return endTurn(s)
    }

    // MARK: - Turn handoff

    private static func endTurn(_ state: State) -> State {
        var s = state
        s.pending = nil
        s.burnSeat = nil
        s.burnResume = nil
        s.exchange = nil
        if livingSeats(s).count <= 1 {
            s.phase = .gameOver
            s.winnerSeat = livingSeats(s).first
            return s
        }
        s.turnActor = nextLivingSeat(after: s.turnActor, s)
        s.phase = .action
        return s
    }

    // MARK: - Action availability (for the UI)

    static func availableActions(_ s: State, seat: Int) -> [Action] {
        if s.coins[seat] >= 10 { return [.beizzati] } // mandatory coup
        var actions: [Action] = [.chai, .rishtedaar, .kiraya, .zardaar]
        if s.coins[seat] >= 3 { actions.append(.bhai) }
        if s.coins[seat] >= 7 { actions.append(.beizzati) }
        // Reorder to a stable, readable layout.
        let order: [Action] = [.chai, .rishtedaar, .kiraya, .raid, .bhai, .zardaar, .beizzati]
        actions.append(.raid)
        return order.filter { actions.contains($0) }
    }

    /// Whether the current responder may block, and with which roles.
    static func blockOptions(_ s: State) -> [Role] {
        guard let pending = s.pending else { return [] }
        let responder = activeSeat(s)
        guard pending.action.blockable else { return [] }
        if pending.action.blockableByTargetOnly {
            return responder == pending.target ? pending.action.blockRoles : []
        }
        return pending.action.blockRoles
    }

    static func canChallengeResponse(_ s: State) -> Bool {
        guard let pending = s.pending else { return false }
        return pending.action.challengeable && !pending.challengeSpent
    }
}

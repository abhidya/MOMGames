# MOM Games — iMessage edition

A native iMessage app that lets two people play turn-based games inside a
Messages conversation. Every turn is encoded into the message bubble itself
(`MSMessage.url`), so there is **no backend and no account system** — Apple's
Messages delivers each move peer-to-peer.

This is built entirely on Apple's `Messages` framework. It contains no
OpenBubbles / OpenPigeon code, so the repository keeps its own license.

## Games

| Game | Logic | UI |
| --- | --- | --- |
| Checkers | `Games/Checkers.swift` | `Views/CheckersView.swift` |
| Archery Duel | `Games/ArcheryDuel.swift` | shared `Views/DuelView.swift` |
| Artillery Duel | `Games/ArtilleryDuel.swift` | shared `Views/DuelView.swift` |
| Launch Duel | `Games/LaunchDuel.swift` | shared `Views/DuelView.swift` |

All game rules are pure, identity-agnostic Swift ported from the original
GDScript modules. Player identity comes from `MSConversation` participant
identifiers, mapped to seats by `GameController`.

## Architecture

```
MessagesViewController (MSMessagesAppViewController)
  └─ hosts SwiftUI RootView
       ├─ GamePickerView            pick a game → GameController.startGame
       └─ GameHostView              turn banner + board
            ├─ CheckersView
            └─ DuelView (archery / artillery / launch)

GameController (ObservableObject)
  • update(with: MSConversation)    decode selected message → MatchEnvelope
  • startGame / commit              build the next MatchEnvelope → MSMessage

MatchEnvelope  ── MatchCoder ──►  base64url payload in MSMessage.url
```

A turn flow: you tap a game (or open a received bubble), make your move, and the
extension inserts a new `MSMessage` in the same session. The recipient taps the
bubble, it decodes to the same state, and they play their move back.

## Building

This project is generated with [XcodeGen](https://github.com/yonyz/XcodeGen) so
the repo stays free of a hand-maintained `.xcodeproj`.

```bash
brew install xcodegen
cd ios
xcodegen generate
open MOMGames.xcodeproj
```

In Xcode:

1. Select the **MOMGames** scheme, set your **Team** under Signing & Capabilities
   for both the app and the `MOMGamesMessages` target (or set `DEVELOPMENT_TEAM`
   in `project.yml` and regenerate).
2. Run on a device or simulator. The app launches Messages; open a conversation,
   tap the Apps drawer, and choose **MOM Games**.
3. To test two-sided play, use two simulators (Messages supports a simulated
   conversation) or two devices signed into different Apple IDs.

## Before shipping

- Add real icon art to `MessagesExtension/Assets.xcassets/iMessage App Icon`
  and `App/Assets.xcassets/AppIcon` (placeholders are checked in).
- iMessage extensions have a tight memory budget; the games here are lightweight
  SwiftUI, but profile on an older device before submission.
- Requires the Apple Developer Program to distribute via TestFlight / App Store.

## Notes / limitations

- State is client-trusted (the sender computes the result), same as GamePigeon.
  That is fine for casual play; there is no server to enforce rules.
- Identity uses per-conversation participant UUIDs, so seats are resolved on
  first move. For 1:1 conversations this is reliable; group conversations are
  out of scope for this slice.

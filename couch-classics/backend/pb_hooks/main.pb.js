onRecordAfterCreateSuccess((e) => {
  const move = e.record
  const matchId = move.get("match")
  if (!matchId) {
    e.next()
    return
  }

  const match = $app.findRecordById("matches", matchId)
  match.set("state", move.get("resulting_state"))
  match.set("status", move.get("status_after"))
  match.set("current_turn", move.get("next_turn"))
  match.set("winner", move.get("winner"))
  $app.save(match)

  const nextTurn = move.get("next_turn")
  if (nextTurn) {
    const notifications = $app.findCollectionByNameOrId("notification_stubs")
    const stub = new Record(notifications)
    stub.set("user", nextTurn)
    stub.set("match", matchId)
    stub.set("kind", "turn_ready")
    stub.set("payload", {
      match_id: matchId,
      game_id: match.get("game_id"),
      turn_number: move.get("turn_number")
    })
    stub.set("delivered", false)
    $app.save(stub)
  }

  e.next()
}, "moves")

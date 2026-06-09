migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  users.listRule = "@request.auth.id != ''"
  users.viewRule = "@request.auth.id != ''"
  users.createRule = ""
  users.updateRule = "id = @request.auth.id"
  users.deleteRule = "id = @request.auth.id"
  users.passwordAuth.enabled = true
  users.passwordAuth.identityFields = ["email"]
  ensureField(users, "handle", new TextField({
    name: "handle",
    required: true,
    min: 3,
    max: 32,
    pattern: "^[a-zA-Z0-9_]+$",
    presentable: true
  }))
  ensureField(users, "display_name", new TextField({
    name: "display_name",
    required: true,
    max: 64,
    presentable: true
  }))
  app.save(users)
  users.addIndex("idx_users_handle", true, "handle", "")
  app.save(users)

  const matches = new Collection({
    type: "base",
    name: "matches",
    listRule: "@request.auth.id != '' && players.id ?= @request.auth.id",
    viewRule: "@request.auth.id != '' && players.id ?= @request.auth.id",
    createRule: "@request.auth.id != ''",
    updateRule: null,
    deleteRule: "@request.auth.id != '' && created_by.id = @request.auth.id",
    fields: [
      { type: "text", name: "game_id", required: true, max: 80 },
      { type: "relation", name: "players", required: true, collectionId: users.id, minSelect: 1, maxSelect: 2 },
      { type: "relation", name: "created_by", required: true, collectionId: users.id, maxSelect: 1 },
      { type: "relation", name: "current_turn", required: false, collectionId: users.id, maxSelect: 1 },
      { type: "json", name: "state", required: true, maxSize: 200000 },
      { type: "select", name: "status", required: true, values: ["waiting", "active", "finished"] },
      { type: "relation", name: "winner", required: false, collectionId: users.id, maxSelect: 1 },
      { type: "text", name: "invite_code", required: false, max: 64 }
    ]
  })
  matches.addIndex("idx_matches_status", false, "status", "")
  matches.addIndex("idx_matches_invite_code", true, "invite_code", "invite_code != ''")
  app.save(matches)

  const moves = new Collection({
    type: "base",
    name: "moves",
    listRule: "@request.auth.id != '' && match.players.id ?= @request.auth.id",
    viewRule: "@request.auth.id != '' && match.players.id ?= @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.player = @request.auth.id && match.players.id ?= @request.auth.id && match.current_turn.id = @request.auth.id && match.status = 'active'",
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "match", required: true, collectionId: matches.id, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "player", required: true, collectionId: users.id, maxSelect: 1 },
      { type: "number", name: "turn_number", required: true, min: 1 },
      { type: "json", name: "move", required: true, maxSize: 50000 },
      { type: "json", name: "resulting_state", required: true, maxSize: 200000 },
      { type: "relation", name: "next_turn", required: false, collectionId: users.id, maxSelect: 1 },
      { type: "relation", name: "winner", required: false, collectionId: users.id, maxSelect: 1 },
      { type: "select", name: "status_after", required: true, values: ["active", "finished"] }
    ]
  })
  moves.addIndex("idx_moves_match_turn", true, "match, turn_number", "")
  app.save(moves)

  const notificationStubs = new Collection({
    type: "base",
    name: "notification_stubs",
    listRule: "@request.auth.id != '' && user.id = @request.auth.id",
    viewRule: "@request.auth.id != '' && user.id = @request.auth.id",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: users.id, maxSelect: 1 },
      { type: "relation", name: "match", required: true, collectionId: matches.id, maxSelect: 1, cascadeDelete: true },
      { type: "text", name: "kind", required: true, max: 40 },
      { type: "json", name: "payload", required: true, maxSize: 20000 },
      { type: "bool", name: "delivered", required: false }
    ]
  })
  notificationStubs.addIndex("idx_notification_stubs_user", false, "user", "")
  app.save(notificationStubs)
}, (app) => {
  for (const name of ["notification_stubs", "moves", "matches"]) {
    try {
      const collection = app.findCollectionByNameOrId(name)
      app.delete(collection)
    } catch (_) {
      // Collection was already removed.
    }
  }
})

function ensureField(collection, name, field) {
  try {
    const existing = collection.fields.getByName(name)
    if (!existing) {
      collection.fields.add(field)
    }
  } catch (_) {
    collection.fields.add(field)
  }
}

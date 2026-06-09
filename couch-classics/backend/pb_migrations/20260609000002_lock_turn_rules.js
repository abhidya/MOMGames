migrate((app) => {
  const matches = app.findCollectionByNameOrId("matches")
  matches.listRule = "@request.auth.id != '' && players.id ?= @request.auth.id"
  matches.viewRule = "@request.auth.id != '' && players.id ?= @request.auth.id"
  matches.createRule = "@request.auth.id != ''"
  matches.updateRule = null
  matches.deleteRule = "@request.auth.id != '' && created_by.id = @request.auth.id"
  app.save(matches)

  const moves = app.findCollectionByNameOrId("moves")
  moves.listRule = "@request.auth.id != '' && match.players.id ?= @request.auth.id"
  moves.viewRule = "@request.auth.id != '' && match.players.id ?= @request.auth.id"
  moves.createRule = "@request.auth.id != '' && @request.body.player = @request.auth.id && match.players.id ?= @request.auth.id && match.current_turn.id = @request.auth.id && match.status = 'active'"
  moves.updateRule = null
  moves.deleteRule = null
  app.save(moves)

  const notificationStubs = app.findCollectionByNameOrId("notification_stubs")
  notificationStubs.listRule = "@request.auth.id != '' && user.id = @request.auth.id"
  notificationStubs.viewRule = "@request.auth.id != '' && user.id = @request.auth.id"
  notificationStubs.createRule = null
  notificationStubs.updateRule = null
  notificationStubs.deleteRule = null
  app.save(notificationStubs)
}, (app) => {
  const matches = app.findCollectionByNameOrId("matches")
  matches.listRule = "@request.auth.id != ''"
  matches.viewRule = "@request.auth.id != ''"
  matches.createRule = "@request.auth.id != ''"
  matches.updateRule = "@request.auth.id != ''"
  matches.deleteRule = "@request.auth.id != ''"
  app.save(matches)

  const moves = app.findCollectionByNameOrId("moves")
  moves.listRule = "@request.auth.id != ''"
  moves.viewRule = "@request.auth.id != ''"
  moves.createRule = "@request.auth.id != ''"
  moves.updateRule = null
  moves.deleteRule = null
  app.save(moves)

  const notificationStubs = app.findCollectionByNameOrId("notification_stubs")
  notificationStubs.listRule = "@request.auth.id != ''"
  notificationStubs.viewRule = "@request.auth.id != ''"
  notificationStubs.createRule = null
  notificationStubs.updateRule = null
  notificationStubs.deleteRule = null
  app.save(notificationStubs)
})

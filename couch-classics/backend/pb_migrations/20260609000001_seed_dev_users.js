migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  const devUsers = [
    { email: "alice@example.test", handle: "alice", display_name: "Alice" },
    { email: "bob@example.test", handle: "bob", display_name: "Bob" }
  ]

  for (const devUser of devUsers) {
    try {
      app.findAuthRecordByEmail("users", devUser.email)
      continue
    } catch (_) {
      const record = new Record(users)
      record.set("email", devUser.email)
      record.set("emailVisibility", true)
      record.set("verified", true)
      record.set("handle", devUser.handle)
      record.set("display_name", devUser.display_name)
      record.set("password", "couchclassics123")
      app.save(record)
    }
  }
}, (app) => {
  for (const email of ["alice@example.test", "bob@example.test"]) {
    try {
      const record = app.findAuthRecordByEmail("users", email)
      app.delete(record)
    } catch (_) {
      // Seed user was already removed.
    }
  }
})

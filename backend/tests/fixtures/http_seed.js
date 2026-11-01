// Somente para testes HTTP isolados, com e-mails e senhas fictícios.
migrate((app) => {
    const users = app.findCollectionByNameOrId("users")
    for (const [email, verified] of [
        ["alice@example.com", true],
        ["bob@example.com", true],
        ["pending@example.com", false],
    ]) {
        const record = new Record(users)
        record.set("email", email)
        record.set("password", "ValidPass9")
        record.set("verified", verified)
        app.save(record)
    }
})

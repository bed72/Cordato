// Executada somente pelo teste opt-in em banco descartável, nunca na imagem.
migrate((app) => {
    function check(condition, message) {
        if (!condition) throw new Error("Verificação descartável: " + message)
    }
    // O runner de migrations ainda pode carregar o cache anterior ao bootstrap.
    app.reloadSettings()
    const settings = app.settings()
    check(settings.meta.appName === "Cordato", "nome")
    check(settings.meta.accentColor === "#27a06c", "cor")
    check(settings.smtp.enabled && settings.smtp.host === "smtp.resend.com" && settings.smtp.port === 465, "SMTP")
    check(settings.smtp.tls && settings.smtp.username === "resend", "SMTP TLS")
    check(settings.batch.enabled === false, "batch desabilitado")
    check(settings.rateLimits.enabled && settings.rateLimits.rules.length === 3, "limites")
    check(settings.backups.cron === "0 0 * * 0" && settings.backups.cronMaxKeep === 3, "backups")
    check(!settings.s3.enabled && !settings.backups.s3.enabled, "armazenamento local")
    const users = app.findCollectionByNameOrId("users")
    const expenses = app.findCollectionByNameOrId("expenses")
    for (const collection of [users, app.findCollectionByNameOrId("_superusers")]) {
        check(collection.verificationTemplate.body.includes("{TOKEN}"), "link de confirmação")
        check(collection.resetPasswordTemplate.body.includes("{TOKEN}"), "link de recuperação")
        check(collection.otp.emailTemplate.body.includes("{OTP}"), "template OTP")
        check(collection.authAlert.emailTemplate.body.includes("{ALERT_INFO}"), "template alerta")
    }
    function user(email, verified) {
        const record = new Record(users)
        record.set("email", email)
        record.set("password", "ValidPass9")
        record.set("verified", verified)
        app.save(record)
        return record
    }
    const alice = user("alice@example.com", true)
    const bob = user("bob@example.com", true)
    const pending = user("pending@example.com", false)
    const expense = new Record(expenses)
    expense.set("owner", alice.id)
    expense.set("amount", 2590)
    app.save(expense)
    check(expense.getString("category") === "", "categoria opcional sem default")
    check(expense.getString("occurred_on") === "", "data opcional sem default")
    check(expense.getString("created") !== "" && expense.getString("updated") !== "", "autodatas")

    function can(record, auth, body, rule) {
        return app.canAccessRecord(record, { auth, body, query: {}, headers: {}, method: "GET" }, rule)
    }
    for (const rule of [expenses.listRule, expenses.viewRule, expenses.deleteRule]) {
        check(can(expense, alice, {}, rule), "acesso próprio")
        check(!can(expense, bob, {}, rule), "isolamento de proprietário")
        check(!can(expense, pending, {}, rule), "bloqueio não verificado")
        check(!can(expense, null, {}, rule), "bloqueio anônimo")
    }
    check(can(expense, alice, {}, expenses.updateRule), "edição própria")
    check(!can(expense, alice, { owner: bob.id }, expenses.updateRule), "bloqueio de transferência")
    check(!can(expense, alice, { created: "2020-01-01 00:00:00.000Z" }, expenses.updateRule), "proteção de timestamp")
    check(!can(alice, alice, { verified: true }, users.updateRule), "proteção de verificação")
    check(!can(alice, bob, {}, users.viewRule), "isolamento de conta")
    check(can(alice, alice, {}, users.viewRule), "leitura de conta própria")
    check(!can(pending, pending, {}, users.authRule), "login exige confirmação")
    check(can(alice, alice, {}, users.authRule), "login verificado")

    function invalidAmount(value) {
        const invalid = new Record(expenses)
        invalid.set("owner", alice.id)
        invalid.set("amount", value)
        let rejected = false
        try { app.validate(invalid) } catch { rejected = true }
        check(rejected, "valor monetário inválido")
    }
    for (const value of [0, -1, 1.5, 9007199254740992]) invalidAmount(value)
    const invalidCategory = new Record(expenses)
    invalidCategory.set("owner", alice.id)
    invalidCategory.set("amount", 1)
    invalidCategory.set("category", "not-a-category")
    let rejected = false
    try { app.validate(invalidCategory) } catch { rejected = true }
    check(rejected, "categoria fora do enum")
    app.delete(alice)
    check(app.countRecords(expenses) === 0, "cascata")
    check(app.countRecords(users) === 2, "preservação das outras contas")
})

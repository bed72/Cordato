migrate((app) => {
    const users = app.findCollectionByNameOrId("users")
    const previousURL = "{APP_URL}/_/#/auth/confirm-verification/{TOKEN}"
    const appURL = "https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}"
    const body = users.verificationTemplate.body
    if (body.includes(appURL) && !body.includes(previousURL)) return
    if (!body.includes(previousURL)) {
        throw new Error("Template de verificação de users personalizado; revisar o destino antes de aplicar a migration de app links.")
    }
    users.verificationTemplate.body = body.split(previousURL).join(appURL)
    app.save(users)
}, () => {
    throw new Error("Rollback automático bloqueado; revisar o template de users sem alterar links administrativos.")
})

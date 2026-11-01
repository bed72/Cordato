migrate((app) => {
    // Exclusiva para instalação nova. Valide tudo antes de gravar, na mesma transação.
    const publicURL = required("POCKETBASE_PUBLIC_URL")
    const adminEmail = required("POCKETBASE_ADMIN_EMAIL")
    const adminPassword = required("POCKETBASE_ADMIN_PASSWORD")
    const smtpPassword = required("SMTP_PASSWORD")
    if ($os.getenv("POCKETBASE_ENCRYPTION_KEY").length !== 32 || app.encryptionEnv() !== "POCKETBASE_ENCRYPTION_KEY") {
        invalid("POCKETBASE_ENCRYPTION_KEY")
    }
    if (!/^https:\/\/[^\s\x00-\x1f\x7f\/?#:@\\]+(?::[0-9]+)?(?:\/[^\s\x00-\x1f\x7f?#\\]*)?$/.test(publicURL)) {
        invalid("POCKETBASE_PUBLIC_URL")
    }

    const existing = app.findAllCollections()
    if (existing.some((collection) => !collection.system && collection.name !== "users")) {
        throw new Error("Bootstrap exclusivo para banco novo; coleções de aplicação já existem.")
    }
    const superusers = app.findCollectionByNameOrId("_superusers")
    if (app.countRecords(superusers) !== 0) {
        throw new Error("Bootstrap exclusivo para banco novo; superusuários já existem.")
    }
    let users = existing.find((collection) => collection.name === "users")
    if (users && (users.type !== "auth" || app.countRecords(users) !== 0)) {
        throw new Error("Bootstrap exclusivo para banco novo; coleção users incompatível ou com dados.")
    }
    if (!users) users = new Collection({ type: "auth", name: "users" })

    const settings = app.settings().clone()
    settings.meta.appName = "Cordato"
    settings.meta.appURL = publicURL
    settings.meta.accentColor = "#27a06c"
    settings.meta.senderName = "Cordato"
    settings.meta.senderAddress = "contato@cordato.cloud"
    settings.smtp.enabled = true
    settings.smtp.host = "smtp.resend.com"
    settings.smtp.port = 465
    settings.smtp.username = "resend"
    settings.smtp.password = smtpPassword
    settings.smtp.tls = true
    settings.smtp.authMethod = "PLAIN"
    settings.smtp.localName = ""
    settings.trustedProxy.headers = ["X-Forwarded-For"]
    settings.trustedProxy.useLeftmostIP = false
    settings.superuserIPs = []
    settings.batch.enabled = false
    settings.rateLimits.enabled = true
    settings.rateLimits.rules = [
        { label: "*:auth", maxRequests: 4, duration: 3, audience: "" },
        { label: "*:create", maxRequests: 30, duration: 6, audience: "" },
        { label: "/api/", maxRequests: 300, duration: 10, audience: "" },
    ]
    settings.rateLimits.excludedIPs = []
    settings.s3.enabled = false
    settings.backups.cron = "0 0 * * 0"
    settings.backups.cronMaxKeep = 3
    settings.backups.s3.enabled = false

    superusers.passwordAuth.enabled = true
    superusers.passwordAuth.identityFields = ["email"]
    superusers.otp.enabled = true
    superusers.otp.duration = 180
    superusers.otp.length = 6
    superusers.mfa.enabled = true
    superusers.mfa.duration = 600
    superusers.mfa.rule = ""
    superusers.authAlert.enabled = true

    users.passwordAuth.enabled = true
    users.passwordAuth.identityFields = ["email"]
    users.oauth2.enabled = false
    users.otp.enabled = false
    users.mfa.enabled = false
    users.authRule = "verified = true"
    users.manageRule = null

    const principal = '@request.auth.id != "" && @request.auth.collectionName = "users" && @request.auth.verified = true'
    const protectedFields = "@request.body.verified:isset = false && @request.body.tokenKey:isset = false" +
        " && @request.body.created:isset = false && @request.body.updated:isset = false"
    users.createRule = protectedFields + " && @request.body.id:isset = false"
    users.listRule = principal + " && id = @request.auth.id"
    users.viewRule = users.listRule
    users.updateRule = users.viewRule + " && " + protectedFields + " && @request.body.id:changed = false"
    users.deleteRule = users.viewRule

    users.fields.removeByName("avatar")
    users.fields.add(new TextField({ name: "avatar", max: 2048 }))
    let name = users.fields.getByName("name")
    if (!name) {
        name = new TextField({ name: "name" })
        users.fields.add(name)
    }
    name.required = false
    name.min = 2
    name.max = 32
    name.pattern = ""
    const password = users.fields.getByName("password")
    password.min = 6
    password.max = 16
    password.pattern = "(?s)([a-z].*[A-Z].*[0-9]|[a-z].*[0-9].*[A-Z]|[A-Z].*[a-z].*[0-9]|[A-Z].*[0-9].*[a-z]|[0-9].*[a-z].*[A-Z]|[0-9].*[A-Z].*[a-z])"
    users.fields.getByName("email").required = true
    addTimestamps(users)
    describe(users, {
        name: "Nome opcional, de 2 a 32 caracteres quando preenchido.",
        avatar: "Seed textual opcional do avatar gerado no Flutter, até 2.048 caracteres. Não é arquivo nem URL de imagem.",
        email: "E-mail usado para login. É necessário confirmar o endereço antes de entrar.",
        emailVisibility: "Controla a visibilidade do e-mail conforme as regras de acesso.",
        verified: "Confirmação do e-mail, gerenciada pelo fluxo nativo do PocketBase.",
        password: "Senha de 6 a 16 caracteres, com letra minúscula ASCII, maiúscula ASCII e número. Nunca retornada pela API.",
        tokenKey: "Chave interna de autenticação. Não compartilhar nem alterar manualmente.",
    })
    for (const collection of [users, superusers]) {
        collection.verificationTemplate = actionTemplate("Confirme seu e-mail", "Confirme seu endereço de e-mail para acessar sua conta Cordato.", "Confirmar e-mail", "confirm-verification")
        collection.resetPasswordTemplate = actionTemplate("Redefina sua senha", "Recebemos uma solicitação para redefinir sua senha.", "Redefinir senha", "confirm-password-reset")
        collection.confirmEmailChangeTemplate = actionTemplate("Confirme seu novo e-mail", "Confirme a alteração do endereço de e-mail da sua conta Cordato.", "Confirmar novo e-mail", "confirm-email-change")
        collection.otp.emailTemplate = emailTemplate("Seu código de acesso", '<p>Use este código para continuar seu acesso ao Cordato:</p><p style="padding:16px;background:#f0f8f4;text-align:center;font-size:28px;letter-spacing:4px;color:#27a06c;"><strong>{OTP}</strong></p><p>Não compartilhe este código.</p>')
        collection.authAlert.emailTemplate = emailTemplate("Novo acesso à sua conta", '<p>Identificamos um acesso à sua conta de um novo local:</p><p style="white-space:pre-wrap;overflow-wrap:anywhere;">{ALERT_INFO}</p><p>Se não reconhece este acesso, altere sua senha.</p>')
    }
    const admin = new Record(superusers)
    admin.set("email", adminEmail)
    admin.set("password", adminPassword)
    try {
        app.validate(admin)
        app.validate(settings)
        app.validate(users)
        app.validate(superusers)
    } catch {
        throw new Error("Configuração inicial inválida; confira URL pública, e-mail e senha do administrador e settings.")
    }

    app.save(users)
    const ownExpense = principal + " && owner = @request.auth.id"
    const expenses = new Collection({
        type: "base",
        name: "expenses",
        listRule: ownExpense,
        viewRule: ownExpense,
        createRule: principal + " && @request.body.owner = @request.auth.id" +
            " && @request.body.created:isset = false && @request.body.updated:isset = false",
        updateRule: ownExpense + " && @request.body.owner:changed = false" +
            " && @request.body.id:changed = false && @request.body.created:isset = false && @request.body.updated:isset = false",
        deleteRule: ownExpense,
        fields: [
            { type: "relation", name: "owner", required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
            { type: "number", name: "amount", required: true, onlyInt: true, min: 1, max: 9007199254740991 },
            { type: "text", name: "description" },
            { type: "date", name: "occurred_on" },
            { type: "select", name: "category", maxSelect: 1, values: [
                "food", "pets", "taxes", "health", "travel", "housing", "leisure", "shopping", "services",
                "transport", "education", "financing", "insurance", "investments", "personal_care",
                "subscriptions", "gifts_and_donations", "other",
            ] },
        ],
        indexes: ["CREATE INDEX idx_expenses_owner_occurred ON expenses (owner, occurred_on, id)"],
    })
    addTimestamps(expenses)
    describe(expenses, {
        owner: "Usuário proprietário. O aplicativo deve enviar o próprio ID; não é permitida transferência. Excluir o usuário remove suas despesas.",
        amount: "Valor positivo em centavos inteiros, entre 1 e 9007199254740991. Exemplo: 2590 representa R$ 25,90.",
        description: "Descrição opcional da despesa.",
        occurred_on: "Data e horário opcionais da despesa, no formato nativo UTC do PocketBase. Sem valor padrão; o aplicativo preenche quando necessário.",
        category: "Categoria opcional da lista compartilhada, gerenciada pelo superusuário. Sem valor padrão; vazio não equivale a other.",
    })
    app.save(expenses)
    app.save(superusers)
    app.save(admin)
    app.save(settings)

    function required(key) {
        const value = $os.getenv(key)
        if (!value || !value.trim()) invalid(key)
        return value
    }
    function invalid(key) {
        throw new Error("Parâmetro inicial ausente ou inválido: " + key + ".")
    }
    function addTimestamps(collection) {
        collection.fields.add(new AutodateField({ name: "created", onCreate: true, onUpdate: false }))
        collection.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }))
    }
    function describe(collection, fields) {
        for (const [key, help] of Object.entries({
            id: "Identificador nativo do PocketBase, gerado automaticamente.",
            created: "Data e horário UTC da criação, preenchidos automaticamente.",
            updated: "Data e horário UTC da última alteração, preenchidos automaticamente.",
            ...fields,
        })) {
            const field = collection.fields.getByName(key)
            if (field) field.help = help
        }
    }
    function emailTemplate(title, content) {
        return {
            subject: title + " — {APP_NAME}",
            body: '<div lang="pt-BR" style="padding:24px 12px;background:#f5f7f6;color:#24332c;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.6;"><div style="max-width:560px;margin:auto;padding:24px;background:white;border:1px solid #dfe8e2;border-radius:12px;"><p style="color:#27a06c;font-size:20px;font-weight:bold;">{APP_NAME}</p><h1 style="font-size:24px;">' + title + '</h1><p>Olá!</p>' + content + '<p style="margin-top:24px;">Equipe Cordato</p></div></div>',
        }
    }
    function actionTemplate(title, message, label, action) {
        const url = "{APP_URL}/_/#/auth/" + action + "/{TOKEN}"
        return emailTemplate(title, '<p>' + message + '</p><p style="margin:24px 0;"><a href="' + url + '" target="_blank" rel="noopener" style="display:inline-block;padding:12px 20px;background:#27a06c;color:white;text-decoration:none;border-radius:6px;">' + label + '</a></p><p>Se o botão não funcionar, copie este link:</p><p style="overflow-wrap:anywhere;"><a href="' + url + '">' + url + '</a></p><p>Se você não solicitou esta ação, ignore este e-mail.</p>')
    }
}, () => {
    throw new Error("Rollback automático bloqueado; preservar usuários, despesas, configurações e credenciais.")
})

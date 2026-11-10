const adminUsername = process.env.NODE_RED_ADMIN_USERNAME;
const credentialSecret = process.env.NODE_RED_CREDENTIAL_SECRET;
const adminPasswordHash = process.env.NODE_RED_ADMIN_PASSWORD_HASH;
const audio = require("./flows/audio/audio.js");

if (!adminUsername || !adminUsername.trim()) {
    throw new Error("Configure NODE_RED_ADMIN_USERNAME.");
}

if (!/^\$2[ab]\$(0[4-9]|[12][0-9]|3[01])\$[./A-Za-z0-9]{53}$/.test(adminPasswordHash || "")) {
    throw new Error("Configure NODE_RED_ADMIN_PASSWORD_HASH com um hash bcrypt válido.");
}

if (!credentialSecret || credentialSecret.trim().length < 32) {
    throw new Error("Configure NODE_RED_CREDENTIAL_SECRET com pelo menos 32 caracteres.");
}

module.exports = {
    uiHost: "0.0.0.0",
    uiPort: 1880,
    userDir: "/data",
    flowFile: "flows.json",
    flowFilePretty: true,
    credentialSecret,
    httpAdminRoot: "/admin",
    httpNodeRoot: "/api",
    httpNodeMiddleware: audio.requestGate,
    functionGlobalContext: { cordatoAudio: audio },
    exportGlobalContextKeys: false,
    adminAuth: {
        type: "credentials",
        sessionExpiryTime: 43200,
        users: [{
            username: adminUsername,
            password: adminPasswordHash,
            permissions: "*",
        }],
    },
    functionExternalModules: false,
    externalModules: {
        autoInstall: false,
        palette: {
            allowInstall: false,
            allowUpdate: false,
            allowUpload: false,
        },
        modules: {
            allowInstall: false,
        },
    },
    editorTheme: {
        projects: { enabled: false },
    },
    diagnostics: { enabled: false, ui: false },
    telemetry: { enabled: false, updateNotification: false },
    logging: {
        console: { level: "info", metrics: false, audit: false },
    },
};

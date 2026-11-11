const { randomUUID } = require("node:crypto");

const MAX_REQUEST_BYTES = 2 * 1024 * 1024 + 65536;
const MESSAGES = Object.freeze({
    unauthorized: "Entre novamente para enviar o áudio.",
    unsupported_format: "Envie um áudio M4A com tipo audio/mp4.",
    payload_too_large: "O áudio deve ter até 2 MiB.",
    length_required: "Informe Content-Length no envio do áudio.",
    busy: "O processamento está ocupado. Tente novamente mais tarde.",
});
let activeRequests = 0;

function requestGate(req, res, next) {
    const requestId = randomUUID();
    req.cordatoAudio = { requestId, startedAt: Date.now() };
    res.setHeader("X-Request-Id", requestId);
    res.setHeader("Cache-Control", "no-store");

    function reject(status, code) {
        console.info(JSON.stringify({ request_id: requestId, event: "request.failed", status, code }));
        res.status(status).json({ request_id: requestId, error: { code, message: MESSAGES[code] } });
    }

    if (!bearerToken(req.headers.authorization)) {
        reject(401, "unauthorized");
        return;
    }

    if (!/^multipart\/form-data\s*;.*\bboundary=(?:"[^"]+"|[^;\s]+)/i.test(req.headers["content-type"] || "")) {
        reject(415, "unsupported_format");
        return;
    }

    const contentLength = req.headers["content-length"];
    if (!/^\d+$/.test(contentLength || "")) {
        reject(411, "length_required");
        return;
    }

    if (!Number.isSafeInteger(Number(contentLength)) || Number(contentLength) > MAX_REQUEST_BYTES) {
        reject(413, "payload_too_large");
        return;
    }

    if (activeRequests >= 4) {
        reject(429, "busy");
        return;
    }

    activeRequests += 1;
    let released = false;
    function release() {
        if (!released) {
            released = true;
            activeRequests -= 1;
        }
    }

    req.cordatoAudio.release = release;
    res.once("finish", () => {
        if (!req.cordatoAudio.processing) {
            release();
        }
    });
    res.once("close", () => {
        if (!req.cordatoAudio.processing) {
            release();
        }
    });
    next();
}

function bearerToken(header) {
    if (typeof header !== "string") {
        return null;
    }

    const token = header.replace(/^Bearer\s+/i, "");
    return /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token) ? token : null;
}

module.exports = requestGate;

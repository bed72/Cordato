# ADR 0005: Opaque auth token, not JWT

Auth is an opaque token, not a self-describing one (JWT). Deliberate: identity's account-deletion
rule requires the session to be invalidated *immediately* as part of the atomic delete, which an opaque
token (deleted server-side on revoke) satisfies trivially — a self-contained token would need a blocklist
or very short TTLs to fake the same guarantee. The token/session concept belongs in `core/` (identity's
README already calls it "domínio compartilhado") once that module exists.

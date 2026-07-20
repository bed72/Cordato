# ADR 0014: The HTTP response envelope

**Supersedes ADR 0008.** Every HTTP `2xx` response now carries its body inside a shared success envelope,
and every failure inside a shared error envelope — both cross-cutting, living in `core/infrastructure/http/
responses/` alongside the builders that shape them, the same place ADR 0008 already put the error contract.
No endpoint returns a bare object/array or the old single-object error body at the top level anymore.

`DataResponse<T>(data: T, meta: MetaResponse? = null, links: LinksResponse? = null)` is the success
envelope: `data` holds the resource — an object for a single item, an array for a collection — and `meta`/
`links` are additive, present only when there is real content to carry (today, only `expense`'s cursor
pagination: `meta.pagination.next_cursor` and `links.self`/`links.next`). They are never serialized as an
empty object or `null` placeholder; they are simply absent. The builders `ok`/`created` in `DataResponses.kt`
compose it, mirroring how `badRequest`/`unprocessable` already composed the error body — `ok(item)` for
`200`, `created(item)` for `201`, both taking the plain `*Response` DTO a controller already had.

`ErrorsResponse(errors: List<ErrorItemResponse>)` replaces the old single-object `ErrorResponse` as the
error body: it is **always an array**, never a lone object. `ErrorItemResponse(status, code, message,
source: ErrorSourceResponse? = null)` is the per-cause item — `status` is the HTTP status as a string
(redundant with the header, kept by convention), `code`/`message` are the same machine/human pair ADR 0008
already defined, and `source.field` (replacing the old `FieldErrorResponse`) appears **only** on a
field-level item. Every invariant ADR 0008 established is preserved byte-for-byte in policy, only the casing
changes: a scalar failure (domain rejection, malformed body, `500`, `401`) is **exactly one** item with no
`source`; an edge Bean Validation failure is one item **per violated field**, each with `source.field`. The
shared builders (`badRequest`/`unauthorized`/`unprocessable`/`internalError`) keep their public
`code`/`message` signature — `badRequest` additionally takes an optional `errors: List<ErrorSourceResponse>`
for the case where several fields share one `code`/`message`; the one caller needing a **different** message
per field (`ConstraintViolationExceptionHandler`) builds its `List<ErrorItemResponse>` directly instead of
going through the builder. No error mapper in any feature had to change its policy — only the return type
(`HttpResponse<ErrorResponse>` → `HttpResponse<ErrorsResponse>`) changed mechanically.

`data` and `errors` are mutually exclusive by construction: `DataResponse`/`ErrorsResponse` are two distinct,
closed types (never a single `Envelope<T>` with both fields optional), so an invalid state — a response
carrying both, or neither — is unrepresentable rather than merely disciplined against.

One Micronaut Serde quirk worth remembering: `DataResponse.data`'s declared type is the generic, erased `T`,
so serde resolves it through the value's *runtime* type rather than a compile-time-known field type — and an
empty collection there defaults to being omitted (as if `NON_EMPTY`), unlike a normal statically-typed
`List<X>` field, which always serializes even when empty. `@field:JsonInclude(JsonInclude.Include.ALWAYS)`
on `data` forces the field to always serialize, so an empty page still returns `"data": []`, never a missing
key. Anyone adding a new generic-wrapper DTO in this codebase should carry the same annotation on its erased
field(s).

`expense`'s `GET /expenses` is the shape's only current `meta`/`links` consumer:
`ExpensePageResponse` (which duplicated `nextCursor` inside the item list) is removed —
`ExpenseResponseMapper.toResponse()` over `ExpensePageVirtualObject` now returns a plain
`List<ExpenseResponse>`, and `ExpenseController` composes `meta.pagination.next_cursor` and
`links.self`/`links.next` itself, deriving `self` from the incoming `HttpRequest` (so it survives the
server's `/v1` context-path without a hardcoded literal) and `links.next` via `UriBuilder.replaceQueryParam`
on that same request URI.

package com.bed.cordato.core.infrastructure.http.openapi

import io.swagger.v3.oas.annotations.info.Info
import io.swagger.v3.oas.annotations.OpenAPIDefinition
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType
import io.swagger.v3.oas.annotations.security.SecurityScheme

/**
 * Global metadata (title/version) for the generated OpenAPI document — the single place the document's
 * identity is declared. It lives in `core`'s cross-cutting HTTP layer, next to the shared error contract,
 * because it describes the API as a whole, not any one feature. The type carries no routing or behaviour;
 * the micronaut-openapi processor reads this annotation at compile-time to seed the generated document,
 * so a bare holder object is enough.
 *
 * The `bearerAuth` [SecurityScheme] is declared here once, as cross-cutting document metadata: an HTTP
 * Bearer scheme every `@Authenticated` route references (via `@SecurityRequirement(name = "bearerAuth")` on
 * its `<Controller>Doc`) so the Swagger UI shows the padlock and lets the caller send a token. Open routes
 * (sign-up, sign-in) declare no requirement, so nothing changes for them. The annotation is inert at runtime.
 *
 * No `@Server` entry is declared for the `/v1` version prefix: the micronaut-openapi processor reads
 * `micronaut.server.context-path` at compile-time and already bakes `/v1` into every documented path
 * (`/v1/persons/me`), so the document is self-consistent against the default `/` server — Swagger UI's
 * "Try it out" hits the real `/v1/...` route. Adding a `@Server(url = "/v1")` on top would double the
 * prefix (`/v1` + `/v1/persons/me`), so the version stays sourced from the one place: the context-path.
 */
@OpenAPIDefinition(
    info = Info(
        version = "1.0",
        title = "Cordato API",
        description = "Cordato — controle de gastos pessoal e de casal.",
    ),
)
@SecurityScheme(
    name = "bearerAuth",
    scheme = "bearer",
    type = SecuritySchemeType.HTTP,
)
object OpenApiDefinition

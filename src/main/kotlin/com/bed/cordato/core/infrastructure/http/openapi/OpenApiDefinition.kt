package com.bed.cordato.core.infrastructure.http.openapi

import io.swagger.v3.oas.annotations.info.Info
import io.swagger.v3.oas.annotations.OpenAPIDefinition

/**
 * Global metadata (title/version) for the generated OpenAPI document — the single place the document's
 * identity is declared. It lives in `core`'s cross-cutting HTTP layer, next to the shared error contract,
 * because it describes the API as a whole, not any one feature. The type carries no routing or behaviour;
 * the micronaut-openapi processor reads this annotation at compile-time to seed the generated document,
 * so a bare holder object is enough.
 */
@OpenAPIDefinition(
    info = Info(
        version = "1.0",
        title = "Cordato API",
        description = "Cordato — controle de gastos pessoal e de casal.",
    ),
)
object OpenApiDefinition

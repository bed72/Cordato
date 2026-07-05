package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.serde.annotation.Serdeable

import io.swagger.v3.oas.annotations.media.Schema

/**
 * A single field-level validation failure inside [ErrorResponse.errors]: [field] is the request field
 * that violated a constraint (the final node of the validation path, never the internal method/argument
 * shape), and [message] is the constraint's own curated text — no raw pattern or internal detail.
 */
@Serdeable
@Schema(description = "Falha de validação de um único campo, dentro de errors.")
data class FieldErrorResponse(
    @field:Schema(description = "Campo da requisição que violou a restrição.", example = "email")
    val field: String,
    @field:Schema(description = "Texto curado da restrição violada.", example = "O e-mail informado é inválido.")
    val message: String,
)

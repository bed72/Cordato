package com.bed.cordato.core.infrastructure.http.responses

import io.micronaut.http.HttpResponse
import io.micronaut.serde.annotation.Serdeable
import io.swagger.v3.oas.annotations.media.Schema
import com.fasterxml.jackson.annotation.JsonInclude

/**
 * The single, shared success envelope used for every HTTP `2xx` response across every bounded context —
 * [data] carries the resource (an object for a single item, an array for a collection), never the domain
 * body directly at the top level. [meta] and [links] are additive and only ever populated when there is
 * real content to carry (e.g. cursor pagination); they stay absent otherwise, never serialized as an empty
 * object. Being cross-cutting (no context knows it exists), it lives in the shared kernel (`core`), not in
 * a feature.
 */
@Serdeable
@Schema(description = "Envelope de sucesso compartilhado por toda resposta HTTP 2xx.")
data class DataResponse<T>(
    // Serde resolves an erased generic property through its runtime-type (not the declared `T`) serializer
    // and defaults an empty collection there to NON_EMPTY — silently dropping the key instead of `[]`. This
    // forces ALWAYS so an empty page still serializes `"data": []`, never omits the field.
    @field:JsonInclude(JsonInclude.Include.ALWAYS)
    @field:Schema(description = "O recurso (objeto) ou a coleção (array) de sucesso.")
    val data: T,
    @field:Schema(description = "Metadado adicional, quando houver (ex.: paginação).")
    val meta: MetaResponse? = null,
    @field:Schema(description = "Links de navegação relacionados ao recurso, quando houver.")
    val links: LinksResponse? = null,
)

/**
 * Additive metadata for a success envelope. Today the only content is [pagination]; future uses
 * (`requestId`, `timestamp`, ...) slot in as new optional fields of this same type, never a per-feature
 * meta type.
 */
@Serdeable
@Schema(description = "Metadado adicional do envelope de sucesso.")
data class MetaResponse(
    @field:Schema(description = "Metadado de paginação por cursor, quando a resposta for uma página.")
    val pagination: PaginationMetaResponse? = null,
)

/** The cursor-pagination metadata: the opaque token for the next page, absent on the last page. */
@Serdeable
@Schema(description = "Metadado de paginação por cursor (keyset).")
data class PaginationMetaResponse(
    @field:Schema(
        nullable = true,
        example = "MjAyNi0wNy0xMHwwMThmOWUyYS03YjNjLTdjNGQtOWUyYS0xYjJjM2Q0ZTVmNjA",
        description = "Cursor opaco para a próxima página, ausente na última página.",
    )
    val nextCursor: String?,
)

/** Navigation links for the current resource: [self] always present, [next] `null` on the last page. */
@Serdeable
@Schema(description = "Links de navegação do envelope de sucesso.")
data class LinksResponse(
    @field:Schema(description = "URL da página/recurso atual.", example = "/v1/expenses?limit=20")
    val self: String,
    @field:Schema(
        nullable = true,
        description = "URL da próxima página, ausente/nula na última página.",
        example = "/v1/expenses?limit=20&cursor=MjAyNi0wNy0xMHwwMThmOWUyYS03YjNjLTdjNGQtOWUyYS0xYjJjM2Q0ZTVmNjA",
    )
    val next: String? = null,
)

/**
 * Shared builders for the [DataResponse] envelope — the reusable "how to shape a success" tijolo that
 * every driving adapter (controller) composes, so no one constructs the envelope inline.
 */

/** `200 OK` — success envelope carrying [item] as `data`, with optional [meta]/[links]. */
fun <T> ok(item: T, meta: MetaResponse? = null, links: LinksResponse? = null): HttpResponse<DataResponse<T>> =
    HttpResponse.ok(DataResponse(item, meta, links))

/** `201 Created` — success envelope carrying the newly created [item] as `data`. */
fun <T> created(item: T): HttpResponse<DataResponse<T>> =
    HttpResponse.created(DataResponse(item))

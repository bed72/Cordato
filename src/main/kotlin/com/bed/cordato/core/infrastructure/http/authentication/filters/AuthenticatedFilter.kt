package com.bed.cordato.core.infrastructure.http.authentication.filters

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpHeaders
import io.micronaut.http.HttpResponse
import io.micronaut.context.BeanProvider
import io.micronaut.web.router.RouteAttributes
import io.micronaut.http.annotation.ServerFilter
import io.micronaut.http.annotation.RequestFilter

import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.application.driven.repositories.SessionRepository
import com.bed.cordato.core.infrastructure.http.responses.unauthorized
import com.bed.cordato.core.infrastructure.http.responses.ErrorResponse
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

/**
 * The edge authentication guard — `core`'s cross-cutting driving filter, the consuming counterpart of the
 * session sign-in *mints*. It is the one place a presented Bearer token is turned into an authenticated
 * actor, and the single origin of a protected route's `401`.
 *
 * Like the controllers and `ExceptionHandler`s, this is an annotation-discovered driving piece (there is no
 * `@Factory` way to declare a filter), so it lives here rather than being wired in `CoreFactory`. It gates
 * on the route's [Authenticated] marker: an unannotated route (sign-up, sign-in) flows through untouched,
 * with **no** session resolution. On an `@Authenticated` route it resolves the live session and either
 * stashes the person id for the honest `AuthenticatedActorArgumentBinder` to read, or **returns** the
 * neutral `401` directly through the shared [unauthorized] builder.
 *
 * Returning — not throwing — mirrors how identity's sign-in mapper already emits the identical
 * `401 UNAUTHENTICATED`: the shared builder owns the shape, so the filter spreads none of it, and there is
 * no dependence on whether a filter-thrown exception routes to a handler. Absent, malformed, expired and
 * revoked tokens all collapse to the same response, so neither status nor body reveals the cause; no
 * `WWW-Authenticate` header is sent and the token is never echoed. [SessionRepository] is injected lazily
 * (`BeanProvider`) so building this singleton at boot does not realize the `DataSource`.
 */
@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)
class AuthenticatedFilter(
    private val clock: ClockPort,
    private val messages: MessagePort,
    private val sessions: BeanProvider<SessionRepository>,
) {
    @RequestFilter
    fun authenticate(request: HttpRequest<*>): HttpResponse<ErrorResponse>? {
        val route = RouteAttributes.getRouteMatch(request).orElse(null)
        if (route == null || !route.annotationMetadata.hasAnnotation(Authenticated::class.java)) return null

        val token = request.bearerToken() ?: return reject()
        val session = sessions.get().findActiveByToken(token, clock()) ?: return reject()

        request.setAttribute(AuthenticatedActor.ATTRIBUTE, session.personId)

        return null
    }

    private fun reject(): HttpResponse<ErrorResponse> =
        unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))
}

private const val BEARER_PREFIX = "Bearer "

/** Reads the token from an `Authorization: Bearer <token>` header, or `null` when absent or malformed. */
private fun HttpRequest<*>.bearerToken(): String? =
    headers[HttpHeaders.AUTHORIZATION]
        ?.takeIf { it.startsWith(BEARER_PREFIX) }
        ?.removePrefix(BEARER_PREFIX)
        ?.takeIf { it.isNotBlank() }

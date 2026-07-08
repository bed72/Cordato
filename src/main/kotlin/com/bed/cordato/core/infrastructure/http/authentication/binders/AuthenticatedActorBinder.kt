package com.bed.cordato.core.infrastructure.http.authentication.binders

import io.micronaut.http.HttpRequest
import io.micronaut.core.type.Argument
import io.micronaut.core.bind.ArgumentBinder.BindingResult
import io.micronaut.core.convert.ArgumentConversionContext
import io.micronaut.http.bind.binders.TypedRequestArgumentBinder

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor

/**
 * The honest half of the edge-auth split: it does **not** authenticate. It only reads the person id that
 * `AuthenticatedFilter` already resolved and stashed under [AuthenticatedActor.ATTRIBUTE], and hands it to
 * the handler as the typed [AuthenticatedActor]. No session lookup, no clock, no exception.
 *
 * An absent attribute yields an **unsatisfied** binding — the case of a handler declaring the actor on a
 * route that is not `@Authenticated` (a programming error, never a legitimate request path), never a `401`
 * (the filter alone owns that). Annotation-free and wired in `CoreFactory`, unlike the discovered filter.
 */
class AuthenticatedActorBinder : TypedRequestArgumentBinder<AuthenticatedActor> {

    override fun argumentType(): Argument<AuthenticatedActor> =
        Argument.of(AuthenticatedActor::class.java)

    override fun bind(
        context: ArgumentConversionContext<AuthenticatedActor>,
        request: HttpRequest<*>,
    ): BindingResult<AuthenticatedActor> {
        val actor = request
            .getAttribute(AuthenticatedActor.ATTRIBUTE, String::class.java)
            .map(::AuthenticatedActor)

        return BindingResult { actor }
    }
}

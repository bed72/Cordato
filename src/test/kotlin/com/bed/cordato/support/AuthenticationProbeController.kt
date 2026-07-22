package com.bed.cordato.support

import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Controller

import com.bed.cordato.core.infrastructure.http.rate_limit.annotations.RateLimited
import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated
import com.bed.cordato.core.infrastructure.http.rate_limit.annotations.RateLimitTierEnum

/**
 * Test fixture exercising the edge-auth guard and the rate limiter end-to-end: an open route the auth
 * filter must ignore (also the `RateLimitFilter`'s `GENERAL`-tier default), an `@Authenticated` route
 * that echoes the resolved [AuthenticatedActor] (also un-annotated for rate limiting, so it doubles as the
 * "rate limit runs before auth" ordering probe), and a `@RateLimited(SENSITIVE)` route with its own,
 * stricter budget. A shared test fixture (not a double), so it lives in `support/` alongside the
 * harnesses, never inline in a test class.
 */
@Controller("/probe")
class AuthenticationProbeController {

    @Get("/open")
    fun open(): String = "open"

    @Authenticated
    @Get("/whoami")
    fun whoami(actor: AuthenticatedActor): String = actor.personId

    @RateLimited(RateLimitTierEnum.SENSITIVE)
    @Get("/sensitive")
    fun sensitive(): String = "sensitive"
}

package com.bed.cordato.support

import io.micronaut.http.annotation.Get
import io.micronaut.http.annotation.Controller

import com.bed.cordato.core.infrastructure.http.authentication.actors.AuthenticatedActor
import com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated

/**
 * Test fixture exercising the edge-auth guard end-to-end: an open route the filter must ignore, and an
 * `@Authenticated` route that echoes the resolved [AuthenticatedActor], so a live session is observable
 * as the id reaching the handler. A shared test fixture (not a double), so it lives in `support/`
 * alongside the harnesses, never inline in a test class.
 */
@Controller("/probe")
class AuthProbeController {

    @Get("/open")
    fun open(): String = "open"

    @Authenticated
    @Get("/whoami")
    fun whoami(actor: AuthenticatedActor): String = actor.personId
}

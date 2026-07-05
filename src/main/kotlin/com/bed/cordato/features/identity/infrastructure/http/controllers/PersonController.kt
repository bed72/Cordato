package com.bed.cordato.features.identity.infrastructure.http.controllers

import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Post
import io.micronaut.http.annotation.Controller
import io.micronaut.validation.Validated

import jakarta.validation.Valid

import com.bed.cordato.features.identity.application.results.SignUpResult
import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase

import com.bed.cordato.features.identity.infrastructure.http.mappers.toCommand
import com.bed.cordato.features.identity.infrastructure.http.mappers.toResponse
import com.bed.cordato.features.identity.infrastructure.http.mappers.toHttpResponse
import com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest

/**
 * Identity's driving (primary/inbound) HTTP adapter. This is the one infrastructure type that
 * carries framework routing annotations: Micronaut discovers `@Controller` beans and reads
 * `@Post` to register routes — there is no factory-based way to declare a route — so, unlike the
 * annotation-free adapters wired in `IdentityModule`, the controller is discovered directly. It
 * still depends only on the pure [SignUpUseCase] (the factory-provided bean, injected here); its
 * public `invoke` is the documented driving side, so no extra port is introduced.
 *
 * `@Validated` + `@Valid` run the request's Bean Validation constraints first: a violation is thrown
 * as a `ConstraintViolationException` (turned into a `400` by
 * [com.bed.cordato.features.identity.infrastructure.http.errors.ConstraintViolationExceptionHandler])
 * before the use case is ever reached. Past that, the handler adds no behavior of its own: it maps the
 * body to a command, runs the use case, and branches over the sealed [SignUpResult]. Because the domain
 * never throws, there is nothing more to catch — success becomes `201 Created`, and each domain error is
 * mapped to its status and neutral body by [toHttpResponse].
 */
@Validated
@Controller
class PersonController(private val signUpUseCase: SignUpUseCase) {

    @Post("/sign-up")
    fun signUp(@Body @Valid request: SignUpRequest): HttpResponse<*> =
        when (val data = signUpUseCase(request.toCommand())) {
            is SignUpResult.Failure -> data.error.toHttpResponse()
            is SignUpResult.Success -> HttpResponse.created(data.person.toResponse())
        }
}

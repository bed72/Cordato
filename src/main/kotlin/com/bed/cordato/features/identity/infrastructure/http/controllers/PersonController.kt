package com.bed.cordato.features.identity.infrastructure.http.controllers

import jakarta.validation.Valid
import io.micronaut.validation.Validated

import io.micronaut.http.HttpStatus
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Body
import io.micronaut.http.annotation.Post
import io.micronaut.http.annotation.Status
import io.micronaut.http.annotation.Controller

import com.bed.cordato.core.application.ports.MessagePort

import com.bed.cordato.features.identity.application.results.SignUpResult
import com.bed.cordato.features.identity.application.results.SignInResult
import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.use_cases.SignInUseCase

import com.bed.cordato.features.identity.infrastructure.http.requests.SignUpRequest
import com.bed.cordato.features.identity.infrastructure.http.requests.SignInRequest
import com.bed.cordato.features.identity.infrastructure.http.mappers.errors.toResponse
import com.bed.cordato.features.identity.infrastructure.http.mappers.requests.toCommand
import com.bed.cordato.features.identity.infrastructure.http.mappers.responses.toResponse
import com.bed.cordato.features.identity.infrastructure.http.controllers.docs.PersonControllerDoc

/**
 * Identity's driving (primary/inbound) HTTP adapter. This is the one infrastructure type that
 * carries framework routing annotations: Micronaut discovers `@Controller` beans and reads
 * `@Post` to register routes — there is no factory-based way to declare a route — so, unlike the
 * annotation-free adapters wired in `IdentityFactory`, the controller is discovered directly. It
 * still depends only on the pure [SignUpUseCase] (the factory-provided bean, injected here); its
 * public `invoke` is the documented driving side, so no extra port is introduced.
 *
 * `@Validated` + `@Valid` run the request's Bean Validation constraints first: a violation is thrown
 * as a `ConstraintViolationException` (turned into a `400` by the shared
 * [com.bed.cordato.core.infrastructure.http.errors.handlers.ConstraintViolationExceptionHandler] in `core`)
 * before the use case is ever reached. Past that, the handler adds no behavior of its own: it maps the
 * body to a command, runs the use case, and branches over the sealed [SignUpResult]. Because the domain
 * never throws, there is nothing more to catch — success becomes `201 Created`, and each domain error is
 * mapped to its status and neutral body by [toResponse], with the message localized via the injected
 * [MessagePort].
 *
 * The OpenAPI documentation lives on the implemented [com.bed.cordato.features.identity.infrastructure.http.controllers.docs.PersonControllerDoc] interface, not here: Micronaut
 * inherits the interface's annotation metadata onto this method, so the controller keeps only routing
 * (`@Controller`/`@Post`), validation (`@Validated`/`@Body`/`@Valid`) and delegation.
 */
@Validated
@Controller
class PersonController(
    private val messages: MessagePort,
    private val signUpUseCase: SignUpUseCase,
    private val signInUseCase: SignInUseCase,
) : PersonControllerDoc {

    @Post("/sign-up")
    @Status(HttpStatus.CREATED)
    override fun signUp(@Body @Valid request: SignUpRequest): HttpResponse<*> =
        when (val data = signUpUseCase(request.toCommand())) {
            is SignUpResult.Failure -> data.error.toResponse(messages)
            is SignUpResult.Success -> HttpResponse.created(data.person.toResponse())
        }

    @Post("/sign-in")
    @Status(HttpStatus.OK)
    override fun signIn(@Body @Valid request: SignInRequest): HttpResponse<*> =
        when (val data = signInUseCase(request.toCommand())) {
            is SignInResult.Failure -> data.error.toResponse(messages)
            is SignInResult.Success -> HttpResponse.ok(data.toResponse())
        }
}

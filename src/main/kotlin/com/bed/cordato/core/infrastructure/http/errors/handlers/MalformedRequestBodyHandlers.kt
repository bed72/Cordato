package com.bed.cordato.core.infrastructure.http.errors.handlers

import jakarta.inject.Singleton

import io.micronaut.json.JsonSyntaxException
import io.micronaut.context.annotation.Replaces

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Produces
import io.micronaut.http.server.exceptions.ExceptionHandler
import io.micronaut.http.server.exceptions.JsonExceptionHandler
import io.micronaut.http.server.exceptions.ConversionErrorHandler
import io.micronaut.http.server.exceptions.UnsatisfiedRouteHandler

import io.micronaut.web.router.exceptions.UnsatisfiedRouteException
import io.micronaut.core.convert.exceptions.ConversionErrorException

import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.badRequest
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse

/**
 * The `400` for a request whose body can't even be read into a command: it never reaches the domain, so
 * there is no per-field breakdown — the failure is scalar (one item, no `source`), in the same shared
 * shape as every other rejection. "Can't be read" arrives as three different framework exceptions — a
 * body that isn't valid JSON, a body that is valid JSON but doesn't match the request shape
 * (missing/mistyped field, so deserialization fails before Bean Validation), and a required body that is
 * absent — so each replaces its own Micronaut default (which would otherwise emit the `_embedded.errors`
 * body) with the same generic, non-leaking `400`. The message is resolved by key through core's
 * [MessagePort]; the `MALFORMED_REQUEST` code stays the inline contract.
 */

/** Body present but not valid JSON (parse failure) → `400`, replacing Micronaut's [JsonExceptionHandler]. */
@Produces
@Singleton
@Replaces(JsonExceptionHandler::class)
class JsonSyntaxExceptionHandler(private val messages: MessagePort) :
    ExceptionHandler<JsonSyntaxException, HttpResponse<ErrorsResponse>> {

    override fun handle(request: HttpRequest<*>, exception: JsonSyntaxException): HttpResponse<ErrorsResponse> =
        badRequest("MALFORMED_REQUEST", messages("error.malformed.message"))
}

/**
 * Valid JSON that doesn't match the request shape (a required field missing or a wrong-typed value), so
 * deserialization fails before the field can even reach Bean Validation → `400`, replacing Micronaut's
 * [ConversionErrorHandler]. This is a shape failure, not a per-field constraint violation, so it stays
 * scalar rather than carrying a `source`.
 */
@Produces
@Singleton
@Replaces(ConversionErrorHandler::class)
class ConversionErrorExceptionHandler(private val messages: MessagePort) :
    ExceptionHandler<ConversionErrorException, HttpResponse<ErrorsResponse>> {

    override fun handle(request: HttpRequest<*>, exception: ConversionErrorException): HttpResponse<ErrorsResponse> =
        badRequest("MALFORMED_REQUEST", messages("error.malformed.message"))
}

/** Required body absent (or another route argument unsatisfied) → `400`, replacing [UnsatisfiedRouteHandler]. */
@Produces
@Singleton
@Replaces(UnsatisfiedRouteHandler::class)
class UnsatisfiedRouteExceptionHandler(private val messages: MessagePort) :
    ExceptionHandler<UnsatisfiedRouteException, HttpResponse<ErrorsResponse>> {

    override fun handle(request: HttpRequest<*>, exception: UnsatisfiedRouteException): HttpResponse<ErrorsResponse> =
        badRequest("MALFORMED_REQUEST", messages("error.malformed.message"))
}

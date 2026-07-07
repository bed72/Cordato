package com.bed.cordato.core.infrastructure.http.authentication.annotations

/**
 * Marks an HTTP route — a `@Controller` class or a handler method — as requiring a live session. The
 * `AuthenticatedFilter` reads this off the matched route: **present** → the request must carry a
 * `Authorization: Bearer` token that resolves to a live session, or it is refused with a neutral `401`
 * *before* the handler runs; **absent** → the route stays open (`sign-up`, `sign-in`).
 *
 * Declaring the annotation is what protects the route — deliberately decoupled from whether the handler
 * consumes the `AuthenticatedActor`. A route may demand a session without ever reading the actor.
 */
@Retention(AnnotationRetention.RUNTIME)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
annotation class Authenticated

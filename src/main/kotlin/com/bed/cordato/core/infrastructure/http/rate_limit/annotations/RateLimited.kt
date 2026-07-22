package com.bed.cordato.core.infrastructure.http.rate_limit.annotations

/**
 * Marks an HTTP route — a `@Controller` class or a handler method — as belonging to the stricter
 * [RateLimitTierEnum.SENSITIVE] budget. Mirrors
 * [com.bed.cordato.core.infrastructure.http.authentication.annotations.Authenticated]'s posture:
 * declaring the annotation is what tightens the route, decoupled from anything the handler itself does.
 *
 * `RateLimitFilter` reads this off the matched route: **present** → count against [tier]'s configured
 * limit/window; **absent** → the route still counts, against [RateLimitTierEnum.GENERAL] — every route is
 * limited by default (per the change's scope), so this annotation only ever *tightens* a specific one,
 * never opts a route out of rate limiting entirely.
 */
@Retention(AnnotationRetention.RUNTIME)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
annotation class RateLimited(val tier: RateLimitTierEnum = RateLimitTierEnum.SENSITIVE)

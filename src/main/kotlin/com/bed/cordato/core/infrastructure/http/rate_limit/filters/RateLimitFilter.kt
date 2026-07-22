package com.bed.cordato.core.infrastructure.http.rate_limit.filters

import io.micronaut.core.order.Ordered
import io.micronaut.core.annotation.Order

import io.micronaut.http.HttpRequest
import io.micronaut.http.HttpResponse
import io.micronaut.web.router.RouteAttributes
import io.micronaut.http.annotation.ServerFilter
import io.micronaut.http.annotation.RequestFilter

import com.bed.cordato.core.application.driven.ports.CachePort
import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.MessagePort
import com.bed.cordato.core.infrastructure.http.responses.ErrorsResponse
import com.bed.cordato.core.infrastructure.http.responses.tooManyRequests
import com.bed.cordato.core.infrastructure.http.rate_limit.RateLimitConfiguration
import com.bed.cordato.core.infrastructure.http.rate_limit.annotations.RateLimited
import com.bed.cordato.core.infrastructure.http.rate_limit.annotations.RateLimitTierEnum

/**
 * The rate-limit guard — `core`'s cross-cutting driving filter that bounds request volume per client IP,
 * on every route, before anything else past the request log runs. `@Order(Ordered.HIGHEST_PRECEDENCE + 1)`
 * places it right after
 * [com.bed.cordato.core.infrastructure.http.logging.HttpRequestLoggingFilter]'s
 * `Ordered.HIGHEST_PRECEDENCE` and before
 * [com.bed.cordato.core.infrastructure.http.authentication.filters.AuthenticatedFilter] (which carries no
 * explicit `@Order`, so it runs at Micronaut's default `0`) — so a request is always counted before the
 * session lookup an `@Authenticated` route would otherwise trigger unthrottled.
 *
 * Implements a fixed-window counter: the window boundary is baked into the cache key itself
 * (`rate_limit:<tier>:<ip>:<window_start>`, `window_start` derived from [ClockPort] — never wall-clock
 * time directly, so this stays deterministic under a fake clock in tests), which is what lets a plain
 * atomic [CachePort.increment] suffice — a key for a new window has never been incremented, so it starts
 * at `1` for free. [CachePort.expire] is called unconditionally after every increment; its `NX` semantics
 * make that safe regardless of whether this was the window's first hit.
 *
 * Tier resolution mirrors [com.bed.cordato.core.infrastructure.http.authentication.filters.AuthenticatedFilter]:
 * the matched route is read via `RouteAttributes.getRouteMatch`, and the presence of [RateLimited] selects
 * [RateLimitTierEnum.SENSITIVE] (or whichever tier it names); its absence — including an unmatched route —
 * defaults to [RateLimitTierEnum.GENERAL], so no route is ever left unlimited.
 *
 * Identity is always the client IP ([HttpRequest.getRemoteAddress]'s host string), never the authenticated
 * person — at the point this filter runs, `AuthenticatedActor` has not been resolved yet (see design.md's
 * Decisions for why this ordering rules out `personId` keying in v1).
 *
 * Over budget → the request is refused directly with the shared [tooManyRequests] `429`
 * (return-not-throw, mirroring `AuthenticatedFilter`'s `401`), short-circuiting before the handler runs.
 */
@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
class RateLimitFilter(
    private val cache: CachePort,
    private val clock: ClockPort,
    private val messages: MessagePort,
    private val general: RateLimitConfiguration.General,
    private val sensitive: RateLimitConfiguration.Sensitive,
) {
    @RequestFilter
    fun limit(request: HttpRequest<*>): HttpResponse<ErrorsResponse>? {
        val tier = tierOf(request)
        val (limit, window) = budgetFor(tier)
        val windowSeconds = window.seconds
        val nowSeconds = clock().epochSecond
        val windowStart = (nowSeconds / windowSeconds) * windowSeconds

        val key = "rate_limit:${tier.name.lowercase()}:${request.remoteAddress.hostString}:$windowStart"
        val count = cache.increment(key)
        cache.expire(key, window)

        if (count <= limit) return null

        val retryAfterSeconds = windowSeconds - (nowSeconds - windowStart)
        return tooManyRequests("RATE_LIMITED", messages("error.rateLimit.message"), retryAfterSeconds)
    }

    private fun tierOf(request: HttpRequest<*>): RateLimitTierEnum {
        val metadata = RouteAttributes.getRouteMatch(request).orElse(null)?.annotationMetadata
            ?: return RateLimitTierEnum.GENERAL

        if (!metadata.hasAnnotation(RateLimited::class.java)) return RateLimitTierEnum.GENERAL

        return metadata
            .enumValue(RateLimited::class.java, "tier", RateLimitTierEnum::class.java)
            .orElse(RateLimitTierEnum.SENSITIVE)
    }

    private fun budgetFor(tier: RateLimitTierEnum) = when (tier) {
        RateLimitTierEnum.GENERAL -> general.limit to general.window
        RateLimitTierEnum.SENSITIVE -> sensitive.limit to sensitive.window
    }
}

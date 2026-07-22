package com.bed.cordato.core.infrastructure.http.rate_limit.annotations

/**
 * The two rate-limit budgets `RateLimitFilter` enforces, each bound to its own
 * [com.bed.cordato.core.infrastructure.http.rate_limit.RateLimitConfiguration] tier. Domain-free edge
 * enum — it names an HTTP-edge concept, not a business one, so it lives beside [RateLimited] rather than
 * in any feature's `domain/enums/`.
 */
enum class RateLimitTierEnum {
    GENERAL,
    SENSITIVE,
}

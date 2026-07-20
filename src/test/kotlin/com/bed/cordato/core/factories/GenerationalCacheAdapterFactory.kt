package com.bed.cordato.core.factories

import java.time.Duration

import com.bed.cordato.core.application.driven.ports.CachePort
import com.bed.cordato.core.infrastructure.adapters.cache.GenerationalCacheAdapter

fun generationalCacheAdapter(
    prefix: String = "test",
    ttl: Duration = Duration.ofSeconds(60),
    cache: CachePort = FakeCachePort(),
): GenerationalCacheAdapter = GenerationalCacheAdapter(prefix = prefix, ttl = ttl, cache = cache)

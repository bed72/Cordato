package com.bed.cordato.core.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.core.application.ports.IdGeneratorPort

fun idGeneratorOf(vararg ids: String): IdGeneratorPort {
    val generator = mockk<IdGeneratorPort>()
    every { generator() } returnsMany ids.toList()
    return generator
}

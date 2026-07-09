package com.bed.cordato.core.factories

import io.mockk.every
import io.mockk.mockk

import com.bed.cordato.core.application.driven.ports.TokenizerPort

fun tokenizerOf(token: String, hash: String): TokenizerPort {
    val tokenizer = mockk<TokenizerPort>()
    every { tokenizer.generate() } returns token
    every { tokenizer.hash(token) } returns hash
    return tokenizer
}

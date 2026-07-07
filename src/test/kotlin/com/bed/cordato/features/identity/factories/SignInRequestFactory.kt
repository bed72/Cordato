package com.bed.cordato.features.identity.factories

fun signInRequestBody(
    password: String = "s3cretpw",
    email: String = "alice@example.com",
): Map<String, String> = mapOf(
    "email" to email,
    "password" to password,
)

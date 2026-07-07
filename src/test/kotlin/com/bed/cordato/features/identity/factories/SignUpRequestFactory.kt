package com.bed.cordato.features.identity.factories

fun signUpRequestBody(
    name: String = "Alice",
    password: String = "s3cretpw",
    email: String = "alice@example.com",
): Map<String, String> = mapOf(
    "name" to name,
    "email" to email,
    "password" to password,
)

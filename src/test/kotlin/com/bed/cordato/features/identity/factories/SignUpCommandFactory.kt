package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.application.driving.commands.SignUpCommand

fun signUpCommand(
    name: String = "Alice",
    password: String = "s3cretpw",
    email: String = "alice@example.com",
): SignUpCommand = SignUpCommand(
    name = name,
    email = email,
    password = password,
)

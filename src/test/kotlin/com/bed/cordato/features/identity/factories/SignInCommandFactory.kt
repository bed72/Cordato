package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.application.commands.SignInCommand

fun signInCommand(
    password: String = "s3cretpw",
    email: String = "alice@example.com",
): SignInCommand = SignInCommand(
    email = email,
    password = password,
)

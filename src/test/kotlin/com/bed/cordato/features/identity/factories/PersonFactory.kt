package com.bed.cordato.features.identity.factories

import com.bed.cordato.features.identity.domain.entities.PersonEntity
import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

fun email(raw: String): EmailValueObject = EmailValueObject.of(raw)!!

fun person(
    id: String = "person-1",
    name: String = "Alice",
    hash: String = "bcrypt:super-secret",
    rawEmail: String = "alice@example.com",
    status: PersonStatusEnum = PersonStatusEnum.ACTIVE,
): PersonEntity = PersonEntity(
    id = id,
    hash = hash,
    status = status,
    email = email(rawEmail),
    name = NameValueObject.of(name)!!,
)

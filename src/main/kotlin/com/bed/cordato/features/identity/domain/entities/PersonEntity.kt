package com.bed.cordato.features.identity.domain.entities

import com.bed.cordato.features.identity.domain.enums.PersonStatusEnum
import com.bed.cordato.features.identity.domain.value_objects.NameValueObject
import com.bed.cordato.features.identity.domain.value_objects.EmailValueObject

/**
 * A person — the anchor every other context references by id. Holds only identity
 * data; owns no money. [hash] is the irreversible hash of the password,
 * never the plaintext; [id] is an opaque identifier produced by the core generator.
 */
data class PersonEntity(
    val id: String,
    val hash: String,
    val name: NameValueObject,
    val email: EmailValueObject,
    val status: PersonStatusEnum,
)

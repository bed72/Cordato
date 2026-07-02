package com.bed.cordato.features.identity.domain.enums

/**
 * The lifecycle state of a person. A person is born [ACTIVE]; the only path to
 * [DELETED] is the account-deletion cycle (out of scope for signup).
 */
enum class PersonStatusEnum {
    ACTIVE,
    DELETED,
}

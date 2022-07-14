package com.commuto.interfacemobile.android.p2p.messages

import com.commuto.interfacemobile.android.key.keys.PublicKey
import java.util.*

/**
 * This represents a [Public Key Announcement](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt#L50).
 *
 * @param id The ID of the offer corresponding to this [PublicKeyAnnouncement].
 * @param publicKey The [PublicKey] that this [PublicKeyAnnouncement] is announcing.
 */
data class PublicKeyAnnouncement constructor(val id: UUID, val publicKey: PublicKey)
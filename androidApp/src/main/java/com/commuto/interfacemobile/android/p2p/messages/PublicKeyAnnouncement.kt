package com.commuto.interfacemobile.android.p2p.messages

import com.commuto.interfacemobile.android.keymanager.types.PublicKey
import java.util.*

data class PublicKeyAnnouncement constructor(val id: UUID, val publicKey: PublicKey)
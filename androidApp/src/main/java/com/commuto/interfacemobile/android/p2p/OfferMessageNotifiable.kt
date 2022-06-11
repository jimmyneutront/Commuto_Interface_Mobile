package com.commuto.interfacemobile.android.p2p

import com.commuto.interfacemobile.android.p2p.messages.PublicKeyAnnouncement

interface OfferMessageNotifiable {
    fun handlePublicKeyAnnouncement(message: PublicKeyAnnouncement)
}
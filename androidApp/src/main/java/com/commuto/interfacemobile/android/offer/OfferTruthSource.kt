package com.commuto.interfacemobile.android.offer

import androidx.compose.runtime.snapshots.SnapshotStateMap
import java.util.*

/**
 * An interface that a class must implement in order to act as a single source of truth for offer-related data.
 * @property offers A [SnapshotStateMap] mapping [UUID]s to [Offer]s that should act as a single source of truth for all
 * offer-related data.
 */
interface OfferTruthSource {
    var offers: SnapshotStateMap<UUID, Offer>

    /**
     * Should add a new [Offer] to [offers].
     *
     * @param offer The new [Offer] that should be added to [offers].
     */
    fun addOffer(offer: Offer)

    /**
     * Should remove from [offers] all [Offer]s with an ID equal to [id]. There should only be one such [Offer].
     *
     * @param id The ID of the [Offer] to remove.
     */
    fun removeOffer(id: UUID)
}
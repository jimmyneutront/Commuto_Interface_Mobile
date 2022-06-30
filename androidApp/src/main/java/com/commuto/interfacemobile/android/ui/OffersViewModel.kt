package com.commuto.interfacemobile.android.ui

import androidx.compose.runtime.mutableStateListOf
import androidx.lifecycle.ViewModel
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.offer.OfferService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The Offers View Model, the single source of truth for all offer-related data. It is observed by offer-related
 * [androidx.compose.runtime.Composable]s.
 *
 * @property offerService The [OfferService] responsible for adding and removing
 * [com.commuto.interfacemobile.android.offer.Offer]s from the list of open offers as they are created, canceled and
 * taken.
 * @property offers A mutable state list of [Offer]s that acts as a single source of truth for all offer-related data.
 */
@Singleton
open class OffersViewModel @Inject constructor(val offerService: OfferService): ViewModel() {
    init {
        offerService.setOffersTruthSource(this)
    }
    var offers = mutableStateListOf<Offer>() //Offer.manySampleOffers

    /**
     * Adds a new [Offer] to [offers].
     *
     * @param offer The new [Offer] to be added to [offers].
     */
    open fun addOffer(offer: Offer) {
        offers.add(offer)
    }
}
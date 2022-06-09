package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.CommutoSwap
import javax.inject.Singleton

@Singleton
interface OfferNotifiable {
    fun handleOfferOpenedEvent(offerEventResponse: CommutoSwap.OfferOpenedEventResponse)
    fun handleOfferTakenEvent(offerTakenEventResponse: CommutoSwap.OfferTakenEventResponse)
}
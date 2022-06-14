package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.CommutoSwap
import javax.inject.Singleton

@Singleton
interface OfferNotifiable {
    fun handleOfferOpenedEvent(offerOpenedEventResponse: CommutoSwap.OfferOpenedEventResponse)
    fun handleOfferCanceledEvent(offerCanceledEventResponse: CommutoSwap.OfferCanceledEventResponse)
    fun handleOfferTakenEvent(offerTakenEventResponse: CommutoSwap.OfferTakenEventResponse)
}
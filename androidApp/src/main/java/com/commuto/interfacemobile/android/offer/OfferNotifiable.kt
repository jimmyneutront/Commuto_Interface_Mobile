package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.blockchain.events.commutoswap.OfferCanceledEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.OfferEditedEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.OfferOpenedEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.OfferTakenEvent
import javax.inject.Singleton

/**
 * An interface that a class must implement in order to be notified of offer-related blockchain events by
 * [com.commuto.interfacemobile.android.blockchain.BlockchainService].
 */
@Singleton
interface OfferNotifiable {
    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of a [OfferOpenedEvent].
     *
     * @param event The [OfferOpenedEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleOfferOpenedEvent(event: OfferOpenedEvent)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of a [OfferEditedEvent].
     *
     * @param event The [OfferEditedEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleOfferEditedEvent(event: OfferEditedEvent)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of a [OfferCanceledEvent].
     *
     * @param event The [OfferCanceledEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleOfferCanceledEvent(event: OfferCanceledEvent)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of a [OfferTakenEvent].
     *
     * @param event The [OfferTakenEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleOfferTakenEvent(event: OfferTakenEvent)
}
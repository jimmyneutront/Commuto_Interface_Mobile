package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import javax.inject.Singleton

/**
 * An interface that a class must implement in order to be notified of offer-related blockchain
 * events by [com.commuto.interfacemobile.android.blockchain.BlockchainService].
 */
@Singleton
interface OfferNotifiable {
    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in
     * order to notify the class implementing this interface of a
     * [CommutoSwap.OfferOpenedEventResponse].
     *
     * @param event The [CommutoSwap.OfferOpenedEventResponse] of which the class
     * implementing this interface is being notified and should handle in the implementation of this
     * method.
     */
    suspend fun handleOfferOpenedEvent(event: CommutoSwap.OfferOpenedEventResponse)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in
     * order to notify the class implementing this interface of a
     * [CommutoSwap.OfferEditedEventResponse].
     *
     * @param event The [CommutoSwap.OfferEditedEventResponse] of which the class
     * implementing this interface is being notified and should handle in the implementation of this
     * method.
     */
    suspend fun handleOfferEditedEvent(event: CommutoSwap.OfferEditedEventResponse)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in
     * order to notify the class implementing this interface of a
     * [CommutoSwap.OfferCanceledEventResponse].
     *
     * @param event The [CommutoSwap.OfferCanceledEventResponse] of which the
     * class implementing this interface is being notified and should handle in the implementation
     * of this method.
     */
    suspend fun handleOfferCanceledEvent(event: CommutoSwap.OfferCanceledEventResponse)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in
     * order to notify the class implementing this interface of a
     * [CommutoSwap.OfferTakenEventResponse].
     *
     * @param event The [CommutoSwap.OfferTakenEventResponse] of which the class
     * implementing this interface is being notified and should handle in the implementation of this
     * method.
     */
    suspend fun handleOfferTakenEvent(event: CommutoSwap.OfferTakenEventResponse)
}
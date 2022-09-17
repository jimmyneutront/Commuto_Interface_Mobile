package com.commuto.interfacemobile.android.swap

import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacemobile.android.offer.OfferService
import java.math.BigInteger
import java.util.*
import javax.inject.Singleton

/**
 * An interface that a class must implement in order to be notified of swap-related events by [BlockchainService] and
 * [OfferService]
 */
@Singleton
interface SwapNotifiable {
    /**
     * The function called by [OfferService] in order to send a taker information message for an offer that has been
     * taken by the user of this interface.
     *
     * @param swapID The ID of the swap for which the structure or class adopting this protocol should announce taker
     * information.
     * @param chainID The ID of the blockchain on which the taken offer exists.
     */
    suspend fun sendTakerInformationMessage(swapID: UUID, chainID: BigInteger)

    /**
     * The function called by [OfferService] when an offer made by the user of this interface has been taken.
     *
     * @param swapID The ID of the offer that has been taken.
     * @param chainID The ID of the blockchain on which the taken offer exists.
     */
    suspend fun handleNewSwap(swapID: UUID, chainID: BigInteger)

    /**
     * The function called by [BlockchainService] in order to notify the class implementing this interface of a
     * [SwapFilledEvent].
     *
     * @param event The [SwapFilledEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleSwapFilledEvent(event: SwapFilledEvent)

    /**
     * The function called by [BlockchainService] in order to notify the class implementing this interface of a
     * [PaymentSentEvent].
     *
     * @param event The [PaymentSentEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handlePaymentSentEvent(event: PaymentSentEvent)

    /**
     * The function called by [BlockchainService] in order to notify the class implementing this interface of a
     * [PaymentReceivedEvent].
     *
     * @param event The [PaymentReceivedEvent] of which the class implementing this interface is being notified and
     * should handle in the implementation of this method.
     */
    suspend fun handlePaymentReceivedEvent(event: PaymentReceivedEvent)

    /**
     * The function called by [BlockchainService] in order to notify the class implementing this interface of a
     * [BuyerClosedEvent].
     *
     * @param event The [BuyerClosedEvent] of which the class implementing this interface is being notified and
     * should handle in the implementation of this method.
     */
    suspend fun handleBuyerClosedEvent(event: BuyerClosedEvent)

    /**
     * The function called by [BlockchainService] in order to notify the class implementing this interface of a
     * [SellerClosedEvent].
     *
     * @param event The [SellerClosedEvent] of which the class implementing this interface is being notified and
     * should handle in the implementation of this method.
     */
    suspend fun handleSellerClosedEvent(event: SellerClosedEvent)
}
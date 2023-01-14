package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.blockchain.BlockchainTransaction
import com.commuto.interfacemobile.android.blockchain.BlockchainTransactionException
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacemobile.android.blockchain.events.erc20.ApprovalEvent
import javax.inject.Singleton

/**
 * An interface that a class must implement in order to be notified of offer-related blockchain events and transaction
 * failures by [com.commuto.interfacemobile.android.blockchain.BlockchainService].
 */
@Singleton
interface OfferNotifiable {
    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface that a monitored offer-related [BlockchainTransaction] has failed (either has
     * been confirmed and failed, or has been dropped.)
     *
     * @param transaction The [BlockchainTransaction] wrapping the on-chain transaction that has failed.
     * @param exception A [BlockchainTransactionException] describing why the on-chain transaction has failed.
     */
    suspend fun handleFailedTransaction(transaction: BlockchainTransaction, exception: BlockchainTransactionException)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of an [ApprovalEvent].
     *
     * @param event The [ApprovalEvent] of which the class implementing this interface is being notified and should
     * handle in the implementation of this method.
     */
    suspend fun handleTokenTransferApprovalEvent(event: ApprovalEvent)

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

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] in order to notify the
     * class implementing this interface of a [ServiceFeeRateChangedEvent].
     *
     * @param event the [ServiceFeeRateChangedEvent] of which
     */
    suspend fun handleServiceFeeRateChangedEvent(event: ServiceFeeRateChangedEvent)
}
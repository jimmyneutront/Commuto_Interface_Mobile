package com.commuto.interfacemobile.android.offer

import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.blockchain.BlockchainTransaction
import com.commuto.interfacemobile.android.blockchain.BlockchainTransactionException
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacemobile.android.blockchain.events.erc20.ApprovalEvent

/**
 * A basic [OfferNotifiable] implementation used to satisfy [BlockchainService]'s offerService dependency for testing
 * non-offer-related code.
 */
class TestOfferService: OfferNotifiable {
    override suspend fun handleFailedTransaction(
        transaction: BlockchainTransaction,
        exception: BlockchainTransactionException
    ) {}
    override suspend fun handleTokenTransferApprovalEvent(event: ApprovalEvent) {}
    override suspend fun handleOfferOpenedEvent(event: OfferOpenedEvent) {}
    override suspend fun handleOfferEditedEvent(event: OfferEditedEvent) {}
    override suspend fun handleOfferCanceledEvent(event: OfferCanceledEvent) {}
    override suspend fun handleOfferTakenEvent(event: OfferTakenEvent) {}
    override suspend fun handleServiceFeeRateChangedEvent(event: ServiceFeeRateChangedEvent) {}
}
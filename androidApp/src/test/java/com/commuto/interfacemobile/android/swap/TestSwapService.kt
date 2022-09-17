package com.commuto.interfacemobile.android.swap

import com.commuto.interfacemobile.android.blockchain.events.commutoswap.BuyerClosedEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.PaymentReceivedEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.PaymentSentEvent
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.SwapFilledEvent
import com.commuto.interfacemobile.android.offer.OfferService
import java.math.BigInteger
import java.util.*

/**
 * A basic [SwapNotifiable] implementation used to satisfy [OfferService]'s swapService dependency for testing
 * non-swap-related code.
 */
class TestSwapService: SwapNotifiable {
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun sendTakerInformationMessage(swapID: UUID, chainID: BigInteger) {}
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun handleNewSwap(swapID: UUID, chainID: BigInteger) {}
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun handleSwapFilledEvent(event: SwapFilledEvent) {}
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun handlePaymentSentEvent(event: PaymentSentEvent) {}
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun handlePaymentReceivedEvent(event: PaymentReceivedEvent) {}
    /**
     * Does nothing, required to adopt [SwapNotifiable]. Should not be used.
     */
    override suspend fun handleBuyerClosedEvent(event: BuyerClosedEvent) {}
}
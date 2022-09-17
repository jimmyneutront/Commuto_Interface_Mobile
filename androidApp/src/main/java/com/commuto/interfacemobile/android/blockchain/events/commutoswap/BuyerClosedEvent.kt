package com.commuto.interfacemobile.android.blockchain.events.commutoswap

import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import java.math.BigInteger
import java.nio.ByteBuffer
import java.util.*

/**
 * Represents a [BuyerClosed](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#buyerclosed) event, emitted
 * by the CommutoSwap smart contract when the buyer closes of a swap closes the swap.
 *
 * @property swapID The ID of the swap that the buyer has closed.
 * @property chainID The ID of the blockchain on which this event was emitted.
 */
data class BuyerClosedEvent(val swapID: UUID, val chainID: BigInteger) {

    companion object {
        /**
         * Creates a [BuyerClosedEvent] from a [CommutoSwap.BuyerClosedEventResponse] and a specified [chainID].
         *
         * @param event The [CommutoSwap.BuyerClosedEventResponse] containing the ID of the swap as a [ByteArray].
         * @param chainID: The ID of the blockchain on which this event was emitted.
         *
         * @return A new [BuyerClosedEvent] with an offer ID as a [UUID] derived from [event]'s swapID ID [ByteArray],
         * and the specified [chainID].
         */
        fun fromEventResponse(event: CommutoSwap.BuyerClosedEventResponse, chainID: BigInteger): BuyerClosedEvent {
            val swapIDByteBuffer = ByteBuffer.wrap(event.swapID)
            val mostSigBits = swapIDByteBuffer.long
            val leastSigBits = swapIDByteBuffer.long
            return BuyerClosedEvent(UUID(mostSigBits, leastSigBits), chainID)
        }
    }
}
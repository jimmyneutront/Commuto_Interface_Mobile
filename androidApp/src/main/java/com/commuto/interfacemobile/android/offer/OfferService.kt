package com.commuto.interfacemobile.android.offer

import androidx.compose.runtime.mutableStateListOf
import com.commuto.interfacemobile.android.CommutoSwap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.nio.ByteBuffer
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfferService @Inject constructor() {
    var offers = mutableStateListOf<Offer>() //Offer.manySampleOffers
    private val scope = CoroutineScope(Dispatchers.Default)

    fun handleNewOffer(offerEventResponse: CommutoSwap.OfferOpenedEventResponse) {
        val offerIdByteBuffer = ByteBuffer.wrap(offerEventResponse.offerID)
        val mostSigBits = offerIdByteBuffer.long
        val leastSigBits = offerIdByteBuffer.long
        val offerId = UUID(mostSigBits, leastSigBits)
        offers.add(Offer(id = offerId, direction = "Buy", price = "1.004", pair = "USD/USDT"),)
    }
}
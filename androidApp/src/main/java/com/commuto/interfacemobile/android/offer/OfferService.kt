package com.commuto.interfacemobile.android.offer

import androidx.compose.runtime.mutableStateListOf
import com.commuto.interfacemobile.android.CommutoSwap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

//TODO: we should only add/remove offers in the main coroutine context
/**
 * The main Offer Service. It is responsible for processing and organizing offer-related data that
 * it receives from [com.commuto.interfacemobile.android.blockchain.BlockchainService] and
 * [com.commuto.interfacemobile.android.p2p.P2PService] in order to maintain an accurate list of all
 * open [Offer]s in [com.commuto.interfacemobile.android.ui.OffersViewModel].
 *
 * @property offers A pointer to the list of all open offers stored in an
 * [com.commuto.interfacemobile.android.ui.OffersViewModel] instance.
 */
@Singleton
class OfferService @Inject constructor(): OfferNotifiable {
    //TODO: Move this back to OffersViewModel
    var offers = mutableStateListOf<Offer>() //Offer.manySampleOffers
    //TODO: Document this if we end up using it
    private val scope = CoroutineScope(Dispatchers.Default)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to notify [OfferService]
     * of an [CommutoSwap.OfferOpenedEventResponse]. Once notified, [OfferService] persistently stores
     * [event], saves it in [offerOpenedEventsRepository] gets all on-chain offer data by calling
     *
     *
     * [OfferService] gets the ID of the new offer from [CommutoSwap.OfferOpenedEventResponse],
     * creates a new [Offer] using the data stored in event, and then adds this new [Offer] to
     * [offers].
     *
     * @param event The [CommutoSwap.OfferOpenedEventResponse] of which
     * [OfferService] is being notified.
     */
    override suspend fun handleOfferOpenedEvent(
        event: CommutoSwap.OfferOpenedEventResponse
    ) {
        val offerIdByteBuffer = ByteBuffer.wrap(event.offerID)
        val mostSigBits = offerIdByteBuffer.long
        val leastSigBits = offerIdByteBuffer.long
        val offerId = UUID(mostSigBits, leastSigBits)
        withContext(Dispatchers.Main) {
            offers.add(Offer(id = offerId, direction = "Buy", price = "1.004", pair = "USD/USDT"))
        }
    }

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to
     * notify [OfferService] of an [CommutoSwap.OfferCanceledEventResponse]. Once notified,
     * [OfferService] gets the ID of the now-canceled offer from
     * [CommutoSwap.OfferCanceledEventResponse] and removes the [Offer] with the specified ID from
     * [offers].
     *
     * @param event The [CommutoSwap.OfferCanceledEventResponse] of which
     * [OfferService] is being notified.
     */
    override suspend fun handleOfferCanceledEvent(
        event: CommutoSwap.OfferCanceledEventResponse
    ) {
        val offerIdByteBuffer = ByteBuffer.wrap(event.offerID)
        val mostSigBits = offerIdByteBuffer.long
        val leastSigBits = offerIdByteBuffer.long
        val offerId = UUID(mostSigBits, leastSigBits)
        withContext(Dispatchers.Main) {
            offers.removeIf { it.id == offerId }
        }
    }


    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to
     * notify [OfferService] of an [CommutoSwap.OfferTakenEventResponse]. Once notified,
     * [OfferService] gets the ID of the now-taken offer from
     * [CommutoSwap.OfferTakenEventResponse] and removes the [Offer] with the specified ID from
     * [offers].
     *
     * @param event The [CommutoSwap.OfferTakenEventResponse] of which
     * [OfferService] is being notified.
     */
    override suspend fun handleOfferTakenEvent(
        event: CommutoSwap.OfferTakenEventResponse
    ) {
        val offerIdByteBuffer = ByteBuffer.wrap(event.offerID)
        val mostSigBits = offerIdByteBuffer.long
        val leastSigBits = offerIdByteBuffer.long
        val offerId = UUID(mostSigBits, leastSigBits)
        withContext(Dispatchers.Main) {
            offers.removeIf { it.id == offerId }
        }
    }
}
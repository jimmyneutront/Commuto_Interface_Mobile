package com.commuto.interfacemobile.android.offer

import com.commuto.interfacedesktop.db.Offer as DatabaseOffer
import com.commuto.interfacemobile.android.contractwrapper.CommutoSwap
import com.commuto.interfacemobile.android.blockchain.BlockchainEventRepository
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.ui.OffersViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The main Offer Service. It is responsible for processing and organizing offer-related data that
 * it receives from [com.commuto.interfacemobile.android.blockchain.BlockchainService] and
 * [com.commuto.interfacemobile.android.p2p.P2PService] in order to maintain an accurate list of all
 * open [Offer]s in [OffersViewModel].
 *
 * @property offerTruthSource The [OffersViewModel] in which this is responsible for maintaining an accurate list of
 * all open offers. If this is not yet initialized, event handling methods will throw the corresponding error.
 * @property offerOpenedEventRepository A repository containing [CommutoSwap.OfferOpenedEventResponse]s for offers that
 * are open and for which complete offer information has not yet been retrieved.
 */
@Singleton
class OfferService (
    private val databaseService: DatabaseService,
    private val offerOpenedEventRepository: BlockchainEventRepository<CommutoSwap.OfferOpenedEventResponse>,
    private val offerCanceledEventRepository: BlockchainEventRepository<CommutoSwap.OfferCanceledEventResponse>
): OfferNotifiable {

    @Inject constructor(databaseService: DatabaseService): this(
        databaseService,
        BlockchainEventRepository(),
        BlockchainEventRepository()
    )

    private lateinit var offerTruthSource: OfferTruthSource

    private lateinit var blockchainService: BlockchainService

    /**
     * Used to set the [offerTruthSource] property. This can only be called once.
     *
     * @param newTruthSource The new value of the [offerTruthSource] property, which cannot be null.
     */
    fun setOfferTruthSource(newTruthSource: OfferTruthSource) {
        check(!::offerTruthSource.isInitialized) {
            "offerTruthSource is already initialized"
        }
        offerTruthSource = newTruthSource
    }

    /**
     * Used to set the [blockchainService] property. This can only be called once.
     *
     * @param newBlockchainService The new value of the [blockchainService]
     */
    fun setBlockchainService(newBlockchainService: BlockchainService) {
        check(!::blockchainService.isInitialized) {
            "blockchainService is already initialized"
        }
        blockchainService = newBlockchainService
    }

    //TODO: Document this if we end up using it
    private val scope = CoroutineScope(Dispatchers.Default)

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to notify [OfferService]
     * of an [CommutoSwap.OfferOpenedEventResponse]. Once notified, [OfferService] saves [event] in
     * [offerOpenedEventRepository], gets all on-chain offer data by calling [blockchainService]'s
     * [BlockchainService.getOfferAsync] method, creates a new [Offer] and list of settlement methods with the results,
     * persistently stores the new offer and its settlement methods, removes [event] from [offerOpenedEventRepository],
     * and then adds the new [Offer] to [offerTruthSource] on the main coroutine dispatcher.
     *
     * @param event The [CommutoSwap.OfferOpenedEventResponse] of which [OfferService] is being notified.
     */
    override suspend fun handleOfferOpenedEvent(
        event: CommutoSwap.OfferOpenedEventResponse
    ) {
        val offerIdByteBuffer = ByteBuffer.wrap(event.offerID)
        val mostSigBits = offerIdByteBuffer.long
        val leastSigBits = offerIdByteBuffer.long
        val offerId = UUID(mostSigBits, leastSigBits)
        val encoder = Base64.getEncoder()
        offerOpenedEventRepository.append(event)
        val onChainOffer = blockchainService.getOfferAsync(offerId).await()
        val offer = Offer(
            id = offerId,
            direction = "Buy",
            price = "1.004",
            pair = "USD/USDT",
            isCreated = onChainOffer.isCreated,
            isTaken = onChainOffer.isTaken,
            maker = onChainOffer.maker,
            interfaceId = onChainOffer.interfaceId,
            stablecoin = onChainOffer.stablecoin,
            amountLowerBound = onChainOffer.amountLowerBound,
            amountUpperBound = onChainOffer.amountUpperBound,
            securityDepositAmount = onChainOffer.securityDepositAmount,
            serviceFeeRate = onChainOffer.serviceFeeRate,
            onChainDirection = onChainOffer.direction,
            onChainPrice = onChainOffer.price,
            settlementMethods = onChainOffer.settlementMethods,
            protocolVersion = onChainOffer.protocolVersion
        )
        val isCreated = if (onChainOffer.isCreated) 1L else 0L
        val isTaken = if (onChainOffer.isTaken) 1L else 0L
        val offerForDatabase = DatabaseOffer(
            offerId = encoder.encodeToString(offerIdByteBuffer.array()),
            isCreated = isCreated,
            isTaken = isTaken,
            maker = offer.maker,
            interfaceId = encoder.encodeToString(offer.interfaceId),
            stablecoin = offer.stablecoin,
            amountLowerBound = offer.amountLowerBound.toString(),
            amountUpperBound = offer.amountUpperBound.toString(),
            securityDepositAmount = offer.securityDepositAmount.toString(),
            serviceFeeRate = offer.serviceFeeRate.toString(),
            onChainDirection = offer.onChainDirection.toString(),
            onChainPrice = encoder.encodeToString(offer.onChainPrice),
            protocolVersion = offer.protocolVersion.toString()
        )
        databaseService.storeOffer(offerForDatabase)
        val settlementMethodStrings = offer.settlementMethods.map {
            encoder.encodeToString(it)
        }
        databaseService.storeSettlementMethods(offerForDatabase.offerId, settlementMethodStrings)
        offerOpenedEventRepository.remove(event)
        withContext(Dispatchers.Main) {
            offerTruthSource.addOffer(offer)
        }
    }

    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to notify [OfferService]
     * of an [CommutoSwap.OfferCanceledEventResponse]. Once notified, [OfferService] saves [event] in
     * [offerCanceledEventRepository], removes the corresponding [Offer] and its settlement methods from persistent
     * storage, removes [event] from [offerCanceledEventRepository], and then removes the corresponding [Offer] from
     * [offerTruthSource] on the main coroutine dispatcher.
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
        val offerIdString = Base64.getEncoder().encodeToString(event.offerID)
        offerCanceledEventRepository.append(event)
        databaseService.deleteOffers(offerIdString)
        databaseService.deleteSettlementMethods(offerIdString)
        offerCanceledEventRepository.remove(event)
        withContext(Dispatchers.Main) {
            offerTruthSource.removeOffer(offerId)
        }
    }


    /**
     * The method called by [com.commuto.interfacemobile.android.blockchain.BlockchainService] to
     * notify [OfferService] of an [CommutoSwap.OfferTakenEventResponse]. Once notified,
     * [OfferService] gets the ID of the now-taken offer from
     * [CommutoSwap.OfferTakenEventResponse] and removes the [Offer] with the specified ID from
     * [offerTruthSource].
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
            offerTruthSource.offers.removeIf { it.id == offerId }
        }
    }
}
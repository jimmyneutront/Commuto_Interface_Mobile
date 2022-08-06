package com.commuto.interfacemobile.android.ui

import android.util.Log
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.commuto.interfacemobile.android.offer.*
import com.commuto.interfacemobile.android.offer.validation.NewOfferDataValidationException
import com.commuto.interfacemobile.android.offer.validation.validateNewOfferData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.math.BigDecimal
import java.math.BigInteger
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The Offers View Model, the single source of truth for all offer-related data. It is observed by offer-related
 * [androidx.compose.runtime.Composable]s.
 *
 * @property logTag The tag passed to [Log] calls.
 * @property offerService The [OfferService] responsible for adding and removing
 * [com.commuto.interfacemobile.android.offer.Offer]s from the list of open offers as they are created, canceled and
 * taken.
 * @property offers A mutable state map of [UUID]s to [Offer]s that acts as a single source of truth for all
 * offer-related data.
 * @property serviceFeeRate The current
 * [service fee rate](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt) as a
 * percentage times 100, or `null` if the current service fee rate is not known.
 * @property isGettingServiceFeeRate Indicates whether this is currently getting the current service fee rate.
 * @property openingOfferState Indicates whether we are currently opening an offer, and if so, the point of the
 * [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt)
 * we are currently in.
 * @property openingOfferException The [Exception] that occured during the offer creation process, or `null` if no such
 * exception has occured.
 */
@Singleton
class OffersViewModel @Inject constructor(private val offerService: OfferService): ViewModel(), UIOfferTruthSource {

    init {
        offerService.setOfferTruthSource(this)
    }

    private val logTag = "OfferViewModel"

    override var offers = mutableStateMapOf<UUID, Offer>().also { map ->
        Offer.sampleOffers.map {
            map[it.id] = it
        }
    }

    override var serviceFeeRate: MutableState<BigInteger?> = mutableStateOf(null)

    override var isGettingServiceFeeRate = mutableStateOf(false)

    override val openingOfferState = mutableStateOf(OpeningOfferState.NONE)

    override var openingOfferException: Exception? = null

    /**
     * Adds a new [Offer] to [offers].
     *
     * @param offer The new [Offer] to be added to [offers].
     */
    override fun addOffer(offer: Offer) {
        offers[offer.id] = offer
    }

    /**
     * Removes the [Offer] with an ID equal to [id] from [offers].
     *
     * @param id The ID of the [Offer] to remove.
     */
    override fun removeOffer(id: UUID) {
        offers.remove(id)
    }

    /**
     * Sets [openingOfferState]'s value on the Main coroutine dispatcher.
     *
     * @param state The new value to which [openingOfferState]'s value will be set.
     */
    private suspend fun setOpeningOfferState(state: OpeningOfferState) {
        withContext(Dispatchers.Main) {
            openingOfferState.value = state
        }
    }

    /**
     * Sets the [Offer.cancelingOfferState] value of the [Offer] in [offers] with the specified [offerID] on the main
     * coroutine dispatcher.
     *
     * @param offerID The ID of the [Offer] of which to set the [Offer.cancelingOfferState].
     * @param state The value to which the [Offer]'s [Offer.cancelingOfferState] will be set.
     */
    private suspend fun setCancelingOfferState(offerID: UUID, state: CancelingOfferState) {
        withContext(Dispatchers.Main) {
            offers[offerID]?.cancelingOfferState?.value = state
        }
    }

    /**
     * Gets the current service fee rate via [offerService] in this view model's coroutine scope and sets
     * [serviceFeeRate] equal to the result in the main coroutine dispatcher..
     */
    override fun updateServiceFeeRate() {
        isGettingServiceFeeRate.value = true
        viewModelScope.launch(Dispatchers.IO) {
            Log.i(logTag, "updateServiceFeeRate: getting value")
            try {
                val newServiceFeeRate = offerService.getServiceFeeRateAsync().await()
                Log.i(logTag, "updateServiceFeeRate: got value")
                withContext(Dispatchers.Main) {
                    serviceFeeRate.value = newServiceFeeRate
                }
                Log.i(logTag, "updateServiceFeeRate: updated value")
            } catch (e: Exception) {
                Log.e(logTag, "updateServiceFeeRate: got exception during getServiceFeeRateAsync call", e)
            }
            delay(700L)
            withContext(Dispatchers.Main) {
                isGettingServiceFeeRate.value = false
            }
        }
    }

    /**
     * Attempts to open a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     *
     * @param chainID The ID of the blockchain on which the offer will be created.
     * @param stablecoin The contract address of the stablecoin for which the offer will be created.
     * @param stablecoinInformation A [StablecoinInformation] about the stablecoin for which the offer will be created.
     * @param minimumAmount The minimum [BigDecimal] amount of the new offer.
     * @param maximumAmount The maximum [BigDecimal] amount of the new offer.
     * @param securityDepositAmount The security deposit [BigDecimal] amount for the new offer.
     * @param direction The direction of the new offer.
     * @param settlementMethods The settlement methods of the new offer.
     */
    override fun openOffer(
        chainID: BigInteger,
        stablecoin: String?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: BigDecimal,
        maximumAmount: BigDecimal,
        securityDepositAmount: BigDecimal,
        direction: OfferDirection?,
        settlementMethods: List<SettlementMethod>
    ) {
        viewModelScope.launch {
            Log.i(logTag, "openOffer: validating new offer data")
            setOpeningOfferState(OpeningOfferState.VALIDATING)
            openingOfferState
            try {
                val serviceFeeRateForOffer = serviceFeeRate.value ?: throw NewOfferDataValidationException("Unable " +
                        "to determine service fee rate")
                val validatedOfferData = validateNewOfferData(
                    stablecoin = stablecoin,
                    stablecoinInformation = stablecoinInformation,
                    minimumAmount = minimumAmount,
                    maximumAmount = maximumAmount,
                    securityDepositAmount = securityDepositAmount,
                    serviceFeeRate = serviceFeeRateForOffer,
                    direction = direction,
                    settlementMethods = settlementMethods
                )
                Log.i(logTag, "openOffer: opening new offer with validated data")
                offerService.openOffer(
                    offerData = validatedOfferData,
                    afterObjectCreation = { setOpeningOfferState(OpeningOfferState.STORING) },
                    afterPersistentStorage = { setOpeningOfferState(OpeningOfferState.APPROVING) },
                    afterTransferApproval = { setOpeningOfferState(OpeningOfferState.OPENING) },
                )
                Log.i(logTag, "openOffer: successfully opened offer")
                setOpeningOfferState(OpeningOfferState.COMPLETED)
            } catch (exception: Exception) {
                Log.e(logTag, "openOffer: got exception during openOffer call", exception)
                openingOfferException = exception
                setOpeningOfferState(OpeningOfferState.EXCEPTION)
            }
        }
    }

    /**
     * Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the
     * user of this interface.
     *
     * @param offer The [Offer] to be canceled.
     */
    override fun cancelOffer(offer: Offer) {
        viewModelScope.launch {
            setCancelingOfferState(
                offerID = offer.id,
                state = CancelingOfferState.CANCELING
            )
            Log.i(logTag, "cancelOffer: canceling offer ${offer.id}")
            try {
                offerService.cancelOffer(
                    offerID = offer.id,
                    chainID = offer.chainID
                )
                Log.i(logTag, "cancelOffer: successfully canceled offer ${offer.id}")
                setCancelingOfferState(
                    offerID = offer.id,
                    state = CancelingOfferState.COMPLETED
                )
            } catch (exception: Exception) {
                Log.i(logTag, "cancelOffer: got exception during cancelOffer call", exception)
                offer.cancelingOfferException = exception
                setCancelingOfferState(
                    offerID = offer.id,
                    state = CancelingOfferState.EXCEPTION
                )
            }
        }
    }

}
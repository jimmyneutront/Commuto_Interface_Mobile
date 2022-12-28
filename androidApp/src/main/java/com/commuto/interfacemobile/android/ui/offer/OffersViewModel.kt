package com.commuto.interfacemobile.android.ui.offer

import android.util.Log
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.commuto.interfacemobile.android.offer.*
import com.commuto.interfacemobile.android.offer.validation.*
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import com.commuto.interfacemobile.android.ui.StablecoinInformation
import com.commuto.interfacemobile.android.ui.StablecoinInformationRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.web3j.crypto.RawTransaction
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
     * Sets the [Offer.editingOfferState] value of the [Offer] in [offers] with the specified [offerID] on the main
     * coroutine dispatcher.
     *
     * @param offerID The ID of the [Offer] of which to set the [Offer.editingOfferState].
     * @param state The value to which the [Offer]'s [Offer.editingOfferState] will be set.
     */
    private suspend fun setEditingOfferState(offerID: UUID, state: EditingOfferState) {
        withContext(Dispatchers.Main) {
            offers[offerID]?.editingOfferState?.value = state
        }
    }

    /**
     * Sets the [Offer.takingOfferState] value of the [Offer] in [offers] ith the specified [offerID] on the main
     * coroutine dispatcher.
     *
     * @param offerID The ID of the [Offer] of which to set the [Offer.takingOfferState].
     * @param state The value to which the [Offer]'s [Offer.takingOfferState] will be set.
     */
    private suspend fun setTakingOfferState(offerID: UUID, state: TakingOfferState) {
        withContext(Dispatchers.Main) {
            offers[offerID]?.takingOfferState?.value = state
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
            setOpeningOfferState(OpeningOfferState.VALIDATING)
            Log.i(logTag, "openOffer: validating new offer data")
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
    @Deprecated("Use the new offer pipeline with improved transaction state management")
    override fun cancelOffer(offer: Offer) {
        viewModelScope.launch {
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
                Log.i(logTag, "cancelOffer: got exception during cancelOffer call for ${offer.id}", exception)
                offer.cancelingOfferException = exception
                setCancelingOfferState(
                    offerID = offer.id,
                    state = CancelingOfferState.EXCEPTION
                )
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] to cancel [offer], which should be made by the user of this interface.
     *
     * This passes [offer]'s ID and chain ID to [OfferService.cancelOffer] and then passes the resulting transaction to
     * [createdTransactionHandler] or exception to [exceptionHandler].
     *
     * @param offer The [Offer] to be canceled.
     * @param createdTransactionHandler An escaping closure that will accept and handle the created [RawTransaction].
     * @param exceptionHandler An escaping closure that will accept and handle any exception that occurs during the
     * transaction creation process.
     */
    override fun createCancelOfferTransaction(
        offer: Offer,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {
        viewModelScope.launch {
            Log.i(logTag, "createCancelOfferTransaction: creating for ${offer.id}")
            try {
                val createdTransaction = offerService.createCancelOfferTransaction(offer.id, offer.chainID)
                createdTransactionHandler(createdTransaction)
            } catch (exception: Exception) {
                exceptionHandler(exception)
            }
        }
    }

    /**
     * Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the
     * user of this interface.
     *
     * This clears any offer-canceling-related exception of [offer], and sets [offer]'s [Offer.cancelingOfferState] to
     * [CancelingOfferState.VALIDATING].
     *
     * @param offer The [Offer] to be canceled.
     * @param offerCancellationTransaction An optional [RawTransaction] that can cancel [offer].
     */
    override fun cancelOffer(offer: Offer, offerCancellationTransaction: RawTransaction?) {
        offer.cancelingOfferException = null
        offer.cancelingOfferState.value = CancelingOfferState.VALIDATING
        viewModelScope.launch {
            Log.i(logTag, "cancelOffer: canceling offer ${offer.id}")
            try {
                offerService.cancelOffer(
                    offer = offer,
                    offerCancellationTransaction = offerCancellationTransaction
                )
                Log.i(logTag, "cancelOffer: successfully broadcast transaction for ${offer.id}")
            } catch (exception: Exception) {
                Log.e(logTag, "cancelOffer: got exception during cancelOffer call for ${offer.id}", exception)
                offer.cancelingOfferException = exception
                setCancelingOfferState(offerID = offer.id, state = CancelingOfferState.EXCEPTION)
            }
        }
    }

    /**
     * Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user
     * of this interface.
     *
     * This validates [newSettlementMethods], passes the offer ID and validated settlement methods to
     * [OfferService.editOffer], and then clears [offer]'s [Offer.selectedSettlementMethods].
     *
     * @param offer The [Offer] to be edited.
     * @param newSettlementMethods A [List] of [SettlementMethod]s with which the [Offer] will be edited.
     */
    override fun editOffer(
        offer: Offer,
        newSettlementMethods: List<SettlementMethod>
    ) {
        viewModelScope.launch {
            setEditingOfferState(
                offerID = offer.id,
                state = EditingOfferState.EDITING
            )
            Log.i(logTag, "editOffer: editing ${offer.id}")
            try {
                Log.i(logTag, "editOffer: validating edited settlement methods for ${offer.id}")
                val validatedSettlementmethods = validateSettlementMethods(newSettlementMethods)
                Log.i(logTag, "editOffer: editing ${offer.id} with validated settlement methods")
                offerService.editOffer(
                    offerID = offer.id,
                    newSettlementMethods = newSettlementMethods
                )
                Log.i(logTag, "editOffer: successfully edited ${offer.id}")
                withContext(Dispatchers.Main) {
                    offer.updateSettlementMethods(
                        settlementMethods = validatedSettlementmethods
                    )
                }
                // We have successfully edited the offer, so we empty the selected settlement method list.
                offer.selectedSettlementMethods.clear()
                setEditingOfferState(
                    offerID = offer.id,
                    state = EditingOfferState.COMPLETED
                )
            } catch (exception: Exception) {
                Log.i(logTag, "editOffer: got exception during editOffer call for ${offer.id}", exception)
                offer.editingOfferException = exception
                setEditingOfferState(
                    offerID = offer.id,
                    state = EditingOfferState.EXCEPTION
                )
            }
        }
    }

    /**
     * Attempts to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     *
     * @param offer The [Offer] to be taken.
     * @param takenSwapAmount The [BigDecimal] amount of stablecoin that the user wants to buy/sell. If the offer has
     * lower and upper bound amounts that ARE equal, this parameter will be ignored.
     * @param makerSettlementMethod The [SettlementMethod], belonging to the maker, that the user/taker has selected to
     * send/receive traditional currency payment.
     * @param takerSettlementMethod The [SettlementMethod], belonging to the user/taker, that the user has selected to
     * send/receive traditional currency payment. This must contain the user's valid private settlement method data, and
     * must have method and currency fields matching [makerSettlementMethod].
     */
    override fun takeOffer(
        offer: Offer,
        takenSwapAmount: BigDecimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
    ) {
        viewModelScope.launch {
            setTakingOfferState(offerID = offer.id, state = TakingOfferState.VALIDATING)
            Log.i(logTag, "takeOffer: validating new swap data for ${offer.id}")
            try {
                // TODO: get the proper stablecoin info repo here
                val validatedSwapData = validateNewSwapData(
                    offer = offer,
                    takenSwapAmount = takenSwapAmount,
                    selectedMakerSettlementMethod = makerSettlementMethod,
                    selectedTakerSettlementMethod = takerSettlementMethod,
                    stablecoinInformationRepository = StablecoinInformationRepository.hardhatStablecoinInfoRepo
                )
                setTakingOfferState(offerID = offer.id, state = TakingOfferState.CHECKING)
                offerService.takeOffer(
                    offerToTake = offer,
                    swapData = validatedSwapData,
                    afterAvailabilityCheck = {
                        setTakingOfferState(
                            offerID = offer.id,
                            state = TakingOfferState.CREATING,
                        )
                    },
                    afterObjectCreation = {
                        setTakingOfferState(
                            offerID = offer.id,
                            state = TakingOfferState.STORING,
                        )
                    },
                    afterPersistentStorage = {
                        setTakingOfferState(
                            offerID = offer.id,
                            state = TakingOfferState.APPROVING,
                        )
                    },
                    afterTransferApproval = {
                        setTakingOfferState(
                            offerID = offer.id,
                            state = TakingOfferState.TAKING,
                        )
                    }
                )
                Log.i(logTag, "takeOffer: successfully took offer ${offer.id}")
                setTakingOfferState(offerID = offer.id, state = TakingOfferState.COMPLETED)
            } catch (exception: Exception) {
                Log.e(logTag, "takeOffer: got error during takeOffer call for ${offer.id}", exception)
                offer.takingOfferException = exception
                setTakingOfferState(offerID = offer.id, state = TakingOfferState.EXCEPTION)
            }
        }
    }

}
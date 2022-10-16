package com.commuto.interfacemobile.android.offer

import android.util.Log
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.snapshots.SnapshotStateList
import com.commuto.interfacemobile.android.blockchain.structs.OfferStruct
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.math.BigInteger
import java.util.*

/**
 * Represents an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 *
 * @param id The ID that uniquely identifies the offer, as a [UUID].
 * @param isCreated The initial value of [isCreated].
 * @param isTaken The initial value of [isTaken].
 * @param maker Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s maker property.
 * @param interfaceId Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s interfaceId property.
 * @param stablecoin Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s stablecoin property.
 * @param amountLowerBound Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s amountLowerBound property.
 * @param amountUpperBound Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s amountUpperBound property.
 * @param securityDepositAmount Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s securityDepositAmount property.
 * @param serviceFeeRate Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s serviceFeeRate property.
 * @param direction The direction of the offer, indicating whether the maker is offering to buy stablecoin or sell
 * stablecoin.
 * @param settlementMethods The initial value of [settlementMethods]
 * @param protocolVersion Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s protocolVersion property.
 * @param chainID The ID of the blockchain on which this Offer exists.
 * @param havePublicKey Indicates whether this interface has a copy of the public key specified by the [interfaceId]
 * property.
 * @param isUserMaker Indicates whether the user of this interface is the maker of this offer.
 * @param state Indicates the current state of this offer, as described in the
 * [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
 *
 * @property isCreated A [MutableState] wrapping a [Boolean] corresponding to an on-chain
 * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s isCreated property.
 * @property isTaken A [MutableState] wrapping a [Boolean] corresponding to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s isTaken property.
 * @property settlementMethods A [SnapshotStateList] of [SettlementMethod]s derived from parsing
 * [onChainSettlementMethods]. Note that this has a private setter; code not in this class should use the
 * [updateSettlementMethods] method.
 * @property serviceFeeAmountLowerBound The minimum service fee for the new offer.
 * @property serviceFeeAmountUpperBound The maximum service fee for the new offer.
 * @property onChainDirection Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s direction property.
 * @property onChainSettlementMethods Corresponds to an on-chain
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s settlementMethods property. Note that
 * this has a private setter; code not in this class should use the [updateSettlementMethodsFromChain] method.
 * @property cancelingOfferState If this offer was made by the user of the interface, this indicates whether the offer
 * is being canceled, and if so, what part of the offer cancellation process it is in. If this offer was not made by the
 * user of this interface, this property is not used.
 * @property cancelingOfferException (This property is used only if the maker of this offer is the user of this
 * interface.) The [Exception] that occurred during the offer cancellation process, or `null` if no such [Exception] has
 * occurred.
 * @property selectedSettlementMethods (This property is used only if the maker of this offer is the user of this
 * interface.) The new [SettlementMethod]s with which the user wants to replace the offer's current settlement methods
 * by editing the offer. If the user is not currently editing this offer, (or if the user is not the maker of this
 * offer) this list should be empty.
 * @property editingOfferState If this offer was made by the user of the interface, this indicates whether the offer is
 * being edited, and if so, what part of the offer editing process it is in. If this offer was not made by the user of
 * this interface, this property is not used.
 * @property editingOfferException (This property is used only if the maker of this offer is the user of this
 * interface.) The [Exception] that occurred during the offer editing process, or `null` if no such exception has
 * occurred.
 * @property takingOfferState (This property is used only if the maker of this offer is NOT the user of this interface.)
 * This indicates whether we are currently taking this offer, and if so, what part of the offer taking process we are
 * in.
 * @property takingOfferException (This property is used only if the maker of this offer is NOT the user of this
 * interface.) The [Exception] that we encountered during the offer editing process, or `null` of no such exception has
 * occurred.
 */
class Offer(
    isCreated: Boolean,
    isTaken: Boolean,
    val id: UUID,
    val maker: String,
    val interfaceId: ByteArray,
    val stablecoin: String,
    val amountLowerBound: BigInteger,
    val amountUpperBound: BigInteger,
    val securityDepositAmount: BigInteger,
    val serviceFeeRate: BigInteger,
    val direction: OfferDirection,
    settlementMethods: SnapshotStateList<SettlementMethod>,
    val protocolVersion: BigInteger,
    val chainID: BigInteger,
    var havePublicKey: Boolean,
    var isUserMaker: Boolean,
    var state: OfferState,
) {

    // TODO: Resolve issue with settlement method decoding in this constructor
    /*
    constructor(
        isCreated: Boolean,
        isTaken: Boolean,
        id: UUID,
        maker: String,
        interfaceId: ByteArray,
        stablecoin: String,
        amountLowerBound: BigInteger,
        amountUpperBound: BigInteger,
        securityDepositAmount: BigInteger,
        serviceFeeRate: BigInteger,
        onChainDirection: BigInteger,
        onChainSettlementMethods: List<ByteArray>,
        protocolVersion: BigInteger,
        chainID: BigInteger,
        havePublicKey: Boolean,
        isUserMaker: Boolean,
        state: OfferState,
    ) : this(
        isCreated = isCreated,
        isTaken = isTaken,
        id = id,
        maker = maker,
        interfaceId = interfaceId,
        stablecoin = stablecoin,
        amountLowerBound = amountLowerBound,
        amountUpperBound = amountUpperBound,
        securityDepositAmount = securityDepositAmount,
        serviceFeeRate = serviceFeeRate,
        direction =
        when (onChainDirection) {
            BigInteger.ZERO -> {
                OfferDirection.BUY
            }
            BigInteger.ONE -> {
                OfferDirection.SELL
            }
            else -> {
                throw IllegalStateException("Unexpected onChainDirection encountered while creating Offer")
            }
        },
        settlementMethods = mutableStateListOf<SettlementMethod>().apply {
            onChainSettlementMethods.forEach {
                try {
                    this.add(Json.decodeFromString(it.decodeToString()))
                } catch (e: Exception) {
                    print(e)
                }
            }
        },
        protocolVersion = protocolVersion,
        chainID = chainID,
        havePublicKey = havePublicKey,
        isUserMaker = isUserMaker,
        state = state,
    )
    */

    val isCreated: MutableState<Boolean>

    val isTaken: MutableState<Boolean>

    var settlementMethods: SnapshotStateList<SettlementMethod> = settlementMethods
        private set

    val serviceFeeAmountLowerBound: BigInteger = this.serviceFeeRate * (this.amountLowerBound /
            BigInteger.valueOf(10_000L))
    val serviceFeeAmountUpperBound: BigInteger = this.serviceFeeRate * (this.amountUpperBound /
            BigInteger.valueOf(10_000L))
    val onChainDirection: BigInteger
    var onChainSettlementMethods: List<ByteArray>
        private set

    val cancelingOfferState: MutableState<CancelingOfferState> = mutableStateOf(CancelingOfferState.NONE)
    var cancelingOfferException: Exception? = null

    val selectedSettlementMethods = mutableStateListOf<SettlementMethod>()
    val editingOfferState: MutableState<EditingOfferState> = mutableStateOf(EditingOfferState.NONE)
    var editingOfferException: Exception? = null

    val takingOfferState: MutableState<TakingOfferState> = mutableStateOf(TakingOfferState.NONE)
    var takingOfferException: Exception? = null

    init {
        this.isCreated = mutableStateOf(isCreated)
        this.isTaken = mutableStateOf(isTaken)
        when (this.direction) {
            OfferDirection.BUY -> {
                this.onChainDirection = BigInteger.ZERO
            }
            OfferDirection.SELL -> {
                this.onChainDirection = BigInteger.ONE
            }
        }
        this.onChainSettlementMethods = settlementMethods.map {
            Json.encodeToString(it).encodeToByteArray()
        }
    }

    /**
     * Updates this [Offer]'s settlement methods given a [List] of [SettlementMethod]s.
     *
     * When called, it serializes the contents of [settlementMethods] and sets [onChainSettlementMethods] equal to a
     * list of the results. Then it sets [Offer.settlementMethods] equal to [settlementMethods].
     *
     * @param settlementMethods An updated [List] of [SettlementMethod]s.
     */
    fun updateSettlementMethods(settlementMethods: List<SettlementMethod>) {
        this.onChainSettlementMethods = settlementMethods.map {
            Json.encodeToString(it).encodeToByteArray()
        }
        this.settlementMethods = mutableStateListOf<SettlementMethod>().apply {
            this.addAll(settlementMethods)
        }
    }

    /**
     * Updates this [Offer]'s settlement methods given a [List] of serialized settlement methods as [ByteArray]s.
     *
     * When called, it deserializes the contents of [onChainSettlementMethods] and sets [settlementMethods] equal to a
     * [List] of the results. Then it sets [Offer.onChainSettlementMethods] equal to [onChainSettlementMethods].
     *
     * @param onChainSettlementMethods An updated [List] of serialized settlement methods as [ByteArray]s.
     * @param logDeserializationExceptions Indicates whether this should log warnings when this is unable to deserialize
     * a [ByteArray].
     */
    fun updateSettlementMethodsFromChain(
        onChainSettlementMethods: List<ByteArray>,
        logDeserializationExceptions: Boolean = false,
    ) {
        val newSettlementMethods = mutableStateListOf<SettlementMethod>().apply {
            this.addAll(onChainSettlementMethods.mapNotNull {
                try {
                    Json.decodeFromString<SettlementMethod>(it.decodeToString())
                } catch (exception: Exception) {
                    if (logDeserializationExceptions) {
                        Log.w("Offer", "updateSettlementMethodsFromChain: got exception while " +
                                "deserializing ${Base64.getEncoder().encodeToString(it)}", exception)
                    }
                    null
                }
            })
        }
        this.settlementMethods = newSettlementMethods
        this.onChainSettlementMethods = onChainSettlementMethods
    }

    /**
     * Returns an [OfferStruct] derived from this [Offer].
     *
     * @return An [OfferStruct] derived from this [Offer].
     */
    fun toOfferStruct(): OfferStruct {
        return OfferStruct(
            isCreated = this.isCreated.value,
            isTaken = this.isTaken.value,
            maker = this.maker,
            interfaceID = this.interfaceId,
            stablecoin = this.stablecoin,
            amountLowerBound = this.amountLowerBound,
            amountUpperBound = this.amountUpperBound,
            securityDepositAmount = this.securityDepositAmount,
            serviceFeeRate = this.serviceFeeRate,
            direction = this.onChainDirection,
            settlementMethods = this.onChainSettlementMethods,
            protocolVersion = this.protocolVersion,
            chainID = this.chainID
        )
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Offer

        if (isCreated != other.isCreated) return false
        if (isTaken != other.isTaken) return false
        if (id != other.id) return false
        if (maker != other.maker) return false
        if (!interfaceId.contentEquals(other.interfaceId)) return false
        if (stablecoin != other.stablecoin) return false
        if (amountLowerBound != other.amountLowerBound) return false
        if (amountUpperBound != other.amountUpperBound) return false
        if (securityDepositAmount != other.securityDepositAmount) return false
        if (serviceFeeRate != other.serviceFeeRate) return false
        if (direction != other.direction) return false
        if (protocolVersion != other.protocolVersion) return false
        if (chainID != other.chainID) return false
        if (havePublicKey != other.havePublicKey) return false
        if (isUserMaker != other.isUserMaker) return false
        if (state != other.state) return false
        if (settlementMethods != other.settlementMethods) return false
        if (serviceFeeAmountLowerBound != other.serviceFeeAmountLowerBound) return false
        if (serviceFeeAmountUpperBound != other.serviceFeeAmountUpperBound) return false
        if (onChainDirection != other.onChainDirection) return false
        if (onChainSettlementMethods != other.onChainSettlementMethods) return false
        if (cancelingOfferState != other.cancelingOfferState) return false
        if (cancelingOfferException != other.cancelingOfferException) return false
        if (selectedSettlementMethods != other.selectedSettlementMethods) return false
        if (editingOfferState != other.editingOfferState) return false
        if (editingOfferException != other.editingOfferException) return false
        if (takingOfferState != other.takingOfferState) return false
        if (takingOfferException != other.takingOfferException) return false

        return true
    }

    override fun hashCode(): Int {
        var result = isCreated.hashCode()
        result = 31 * result + isTaken.hashCode()
        result = 31 * result + id.hashCode()
        result = 31 * result + maker.hashCode()
        result = 31 * result + interfaceId.contentHashCode()
        result = 31 * result + stablecoin.hashCode()
        result = 31 * result + amountLowerBound.hashCode()
        result = 31 * result + amountUpperBound.hashCode()
        result = 31 * result + securityDepositAmount.hashCode()
        result = 31 * result + serviceFeeRate.hashCode()
        result = 31 * result + direction.hashCode()
        result = 31 * result + protocolVersion.hashCode()
        result = 31 * result + chainID.hashCode()
        result = 31 * result + havePublicKey.hashCode()
        result = 31 * result + isUserMaker.hashCode()
        result = 31 * result + state.hashCode()
        result = 31 * result + settlementMethods.hashCode()
        result = 31 * result + serviceFeeAmountLowerBound.hashCode()
        result = 31 * result + serviceFeeAmountUpperBound.hashCode()
        result = 31 * result + onChainDirection.hashCode()
        result = 31 * result + onChainSettlementMethods.hashCode()
        result = 31 * result + cancelingOfferState.hashCode()
        result = 31 * result + (cancelingOfferException?.hashCode() ?: 0)
        result = 31 * result + selectedSettlementMethods.hashCode()
        result = 31 * result + editingOfferState.hashCode()
        result = 31 * result + (editingOfferException?.hashCode() ?: 0)
        result = 31 * result + takingOfferState.hashCode()
        result = 31 * result + (takingOfferException?.hashCode() ?: 0)
        return result
    }

    companion object {
        /**
         * A [List] of sample [Offer]s. Used for previewing offer-related Composable functions.
         */
        val sampleOffers = listOf(
            fromOnChainData(
                isCreated = true,
                isTaken = false,
                id = UUID.randomUUID(),
                maker = "0x0000000000000000000000000000000000000000",
                interfaceId = ByteArray(0),
                stablecoin = "0x663F3ad617193148711d28f5334eE4Ed07016602", // DAI on Hardhat
                amountLowerBound = BigInteger.valueOf(10_000) * BigInteger.TEN.pow(18),
                amountUpperBound = BigInteger.valueOf(20_000) * BigInteger.TEN.pow(18),
                securityDepositAmount = BigInteger.valueOf(1_000) * BigInteger.TEN.pow(18),
                serviceFeeRate = BigInteger.valueOf(100),
                onChainDirection = BigInteger.ZERO,
                onChainSettlementMethods = listOf(
                    """
                    {
                        "f": "EUR",
                        "p": "0.94",
                        "m": "SEPA"
                    }
                    """.trimIndent().encodeToByteArray()
                ),
                protocolVersion = BigInteger.ZERO,
                chainID = BigInteger.valueOf(31337L), // Hardhat blockchain ID
                havePublicKey = false,
                isUserMaker = true,
                state = OfferState.OFFER_OPENED
            ),
            fromOnChainData(
                isCreated = true,
                isTaken = false,
                id = UUID.randomUUID(),
                maker = "0x0000000000000000000000000000000000000000",
                interfaceId = ByteArray(0),
                stablecoin = "0x2E983A1Ba5e8b38AAAeC4B440B9dDcFBf72E15d1", // USDC on Hardhat
                amountLowerBound = BigInteger.valueOf(10_000) * BigInteger.TEN.pow(6),
                amountUpperBound = BigInteger.valueOf(20_000) * BigInteger.TEN.pow(6),
                securityDepositAmount = BigInteger.valueOf(1_000) * BigInteger.TEN.pow(6),
                serviceFeeRate = BigInteger.valueOf(10),
                onChainDirection = BigInteger.ONE,
                onChainSettlementMethods = listOf(
                    """
                    {
                        "f": "USD",
                        "p": "1.00",
                        "m": "SWIFT"
                    }
                    """.trimIndent().encodeToByteArray()
                ),
                protocolVersion = BigInteger.ZERO,
                chainID = BigInteger.valueOf(31337L), // Hardhat blockchain ID
                havePublicKey = false,
                isUserMaker = true,
                state = OfferState.OFFER_OPENED
            ),
            fromOnChainData(
                isCreated = true,
                isTaken = false,
                id = UUID.randomUUID(),
                maker = "0x0000000000000000000000000000000000000000",
                interfaceId = ByteArray(0),
                stablecoin = "0x8438Ad1C834623CfF278AB6829a248E37C2D7E3f", // BUSD on Hardhat
                amountLowerBound = BigInteger.valueOf(10_000) * BigInteger.TEN.pow(18),
                amountUpperBound = BigInteger.valueOf(20_000) * BigInteger.TEN.pow(18),
                securityDepositAmount = BigInteger.valueOf(2_000) * BigInteger.TEN.pow(18),
                serviceFeeRate = BigInteger.valueOf(1),
                onChainDirection = BigInteger.ONE,
                onChainSettlementMethods = listOf(
                    """
                    {
                        "f": "BSD",
                        "p": "1.00",
                        "m": "SANDDOLLAR"
                    }
                    """.trimIndent().encodeToByteArray()
                ),
                protocolVersion = BigInteger.ZERO,
                chainID = BigInteger.valueOf(31337L), // Hardhat blockchain ID
                havePublicKey = true,
                isUserMaker = false,
                state = OfferState.OFFER_OPENED
            ),
            fromOnChainData(
                isCreated = true,
                isTaken = false,
                id = UUID.randomUUID(),
                maker = "0x0000000000000000000000000000000000000000",
                interfaceId = ByteArray(0),
                /*
                UniswapV3Factory on Ethereum Mainnet, definitely not a stablecoin contract
                 */
                stablecoin = "0x1F98431c8aD98523631AE4a59f267346ea31F984",
                amountLowerBound = BigInteger.valueOf(10_000) * BigInteger.TEN.pow(18),
                amountUpperBound = BigInteger.valueOf(10_000) * BigInteger.TEN.pow(18),
                securityDepositAmount = BigInteger.valueOf(1_000) * BigInteger.TEN.pow(18),
                serviceFeeRate = BigInteger.valueOf(100),
                onChainDirection = BigInteger.ONE,
                onChainSettlementMethods = listOf("not valid JSON".encodeToByteArray()),
                protocolVersion = BigInteger.ZERO,
                chainID = BigInteger.ONE, // Ethereum Mainnet blockchain ID
                havePublicKey = false,
                isUserMaker = false,
                state = OfferState.OFFER_OPENED
            ),
        )

        /**
         * Creates a new [Offer] using on-chain direction and settlement method data.
         *
         * @param isCreated: The desired value of the [Offer.isCreated] property.
         * @param isTaken: The desired value of the [Offer.isTaken] property.
         * @param id: The offer's ID.
         * @param maker: The desired value of the [Offer.maker] property.
         * @param interfaceId: The desired value of the [Offer.interfaceId] property.
         * @param stablecoin The desired value of the [Offer.stablecoin] property.
         * @param amountLowerBound The desired value of the [Offer.amountLowerBound] property.
         * @param amountUpperBound The desired value of the [Offer.amountUpperBound] property.
         * @param securityDepositAmount The desired value of the [Offer.securityDepositAmount] property.
         * @param serviceFeeRate The desired value of the [Offer.serviceFeeRate] property.
         * @param onChainDirection Corresponds to an on-chain
         * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s direction property, from which
         * the value of the [direction] property will be derived.
         * @param onChainSettlementMethods Corresponds to an on-chain
         * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s settlementMethods property,
         * from which the value of the [settlementMethods] property will be derived.
         * @param protocolVersion The desired value of the [Offer.protocolVersion] property.
         * @param chainID The desired value of the [Offer.chainID] property.
         * @param havePublicKey The desired value of the [Offer.havePublicKey] property.
         * @param isUserMaker The desired value of the [Offer.isUserMaker] property.
         * @param state The desired value of the [Offer.state] property.
         * @param logDeserializationExceptions Indicates whether this should log warnings when this is unable to
         * deserialize a [ByteArray].
         *
         * @return A new [Offer], with its [Offer.direction] property derived from the passed [onChainDirection] value
         * and  its [Offer.settlementMethods] property created by deserializing the data passed in
         * [onChainSettlementMethods]
         *
         * @throws IllegalStateException If [onChainDirection] is neither [BigInteger.ZERO] (indicating a buy offer) or
         * [BigInteger.ONE] indicating a sell offer.
         */
        fun fromOnChainData(
            isCreated: Boolean,
            isTaken: Boolean,
            id: UUID,
            maker: String,
            interfaceId: ByteArray,
            stablecoin: String,
            amountLowerBound: BigInteger,
            amountUpperBound: BigInteger,
            securityDepositAmount: BigInteger,
            serviceFeeRate: BigInteger,
            onChainDirection: BigInteger,
            onChainSettlementMethods: List<ByteArray>,
            protocolVersion: BigInteger,
            chainID: BigInteger,
            havePublicKey: Boolean,
            isUserMaker: Boolean,
            state: OfferState,
            logDeserializationExceptions: Boolean = false,
        ): Offer {
            val direction = when (onChainDirection) {
                BigInteger.ZERO -> {
                    OfferDirection.BUY
                }
                BigInteger.ONE -> {
                    OfferDirection.SELL
                }
                else -> {
                    throw IllegalStateException("Unexpected onChainDirection encountered while creating Offer")
                }
            }
            val settlementMethods = mutableStateListOf<SettlementMethod>().apply {
                onChainSettlementMethods.forEach {
                    try {
                        this.add(Json.decodeFromString(it.decodeToString()))
                    } catch (exception: Exception) {
                        if (logDeserializationExceptions) {
                            Log.w("Offer", "updateSettlementMethodsFromChain: got exception while " +
                                    "deserializing ${Base64.getEncoder().encodeToString(it)}", exception)
                        }
                    }
                }
            }
            return Offer(
                isCreated = isCreated,
                isTaken = isTaken,
                id = id,
                maker = maker,
                interfaceId = interfaceId,
                stablecoin = stablecoin,
                amountLowerBound = amountLowerBound,
                amountUpperBound = amountUpperBound,
                securityDepositAmount = securityDepositAmount,
                serviceFeeRate = serviceFeeRate,
                direction = direction,
                settlementMethods = settlementMethods,
                protocolVersion = protocolVersion,
                chainID = chainID,
                havePublicKey = havePublicKey,
                isUserMaker = isUserMaker,
                state = state,
            )
        }

    }

}
package com.commuto.interfacemobile.android.swap

import android.util.Log
import com.commuto.interfacedesktop.db.Swap as DatabaseSwap
import com.commuto.interfacemobile.android.blockchain.BlockchainService
import com.commuto.interfacemobile.android.blockchain.BlockchainTransaction
import com.commuto.interfacemobile.android.blockchain.BlockchainTransactionException
import com.commuto.interfacemobile.android.blockchain.BlockchainTransactionType
import com.commuto.interfacemobile.android.blockchain.events.commutoswap.*
import com.commuto.interfacemobile.android.database.DatabaseService
import com.commuto.interfacemobile.android.extension.asByteArray
import com.commuto.interfacemobile.android.key.KeyManagerService
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.offer.OfferDirection
import com.commuto.interfacemobile.android.offer.OfferService
import com.commuto.interfacemobile.android.p2p.P2PService
import com.commuto.interfacemobile.android.p2p.SwapMessageNotifiable
import com.commuto.interfacemobile.android.p2p.messages.MakerInformationMessage
import com.commuto.interfacemobile.android.p2p.messages.TakerInformationMessage
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import com.commuto.interfacemobile.android.swap.validation.validateSwapForClosing
import com.commuto.interfacemobile.android.swap.validation.validateSwapForReportingPaymentReceived
import com.commuto.interfacemobile.android.swap.validation.validateSwapForReportingPaymentSent
import com.commuto.interfacemobile.android.util.DateFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import org.web3j.crypto.Hash
import org.web3j.crypto.RawTransaction
import org.web3j.utils.Numeric
import java.math.BigInteger
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The main Swap Service. It is responsible for processing and organizing swap-related data that it receives from
 * [BlockchainService], [P2PService] and [OfferService] in order to maintain an accurate list of all swaps in a
 * [SwapTruthSource].
 *
 * @property databaseService The [DatabaseService] that this [SwapService] uses for persistent storage.
 * @property keyManagerService The [KeyManagerService] that this [SwapService] will use for managing keys.
 * @property swapTruthSource The [SwapTruthSource] in which this is responsible for maintaining an accurate list of
 * swaps. If this is not yet initialized, event handling methods will throw the corresponding error.
 * @property blockchainService The [BlockchainService] that this uses to interact with the blockchain.
 * @property p2pService The [P2PService] that this uses for interacting with the peer-to-peer network.
 */
@Singleton
class SwapService @Inject constructor(
    private val databaseService: DatabaseService,
    private val keyManagerService: KeyManagerService,
): SwapNotifiable, SwapMessageNotifiable {

    private lateinit var swapTruthSource: SwapTruthSource

    private lateinit var blockchainService: BlockchainService

    private lateinit var p2pService: P2PService

    private val logTag = "SwapService"

    /**
     * Used to set the [swapTruthSource] property. This can only be called once.
     *
     * @param newTruthSource The new value of the [swapTruthSource] property, which cannot be null.
     */
    fun setSwapTruthSource(newTruthSource: SwapTruthSource) {
        check(!::swapTruthSource.isInitialized) {
            "swapTruthSource is already initialized"
        }
        swapTruthSource = newTruthSource
    }

    /**
     * Used to set the [blockchainService] property. This can only be called once.
     *
     * @param newBlockchainService The new value of the [blockchainService] property, which cannot be null.
     */
    fun setBlockchainService(newBlockchainService: BlockchainService) {
        check(!::blockchainService.isInitialized) {
            "blockchainService is already initialized"
        }
        blockchainService = newBlockchainService
    }

    /**
     * Used to set the [p2pService] property. This can only be called once.
     *
     * @param newP2PService The new value of the [p2pService] property, which cannot be null.
     */
    fun setP2PService(newP2PService: P2PService) {
        check(!::p2pService.isInitialized) {
            "p2pService is already initialized"
        }
        p2pService = newP2PService
    }

    /**
     * If [swapID] and [chainID] correspond to an offer taken by the user of this interface, this sends a
     * [Taker Information Message](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt):
     * this updates the state of the swap with the specified ID (both persistently and in [swapTruthSource]) to
     * [SwapState.AWAITING_TAKER_INFORMATION], creates and sends a Taker Information Message, and then updates the state
     * of the swap with the specified ID (both persistently and in [swapTruthSource]) to
     * [SwapState.AWAITING_MAKER_INFORMATION], and then returns `true` to indicate that the swap was taken by the user
     * of this interface and thus the message has been sent. If [swapID] and [chainID] do not correspond to an offer
     * taken by the user of this interface, this returns `false`.
     *
     * @param swapID The ID of the swap for which taker information should be sent.
     * @param chainID The ID of the blockchain on which the swap exists.
     */
    override suspend fun sendTakerInformationMessage(swapID: UUID, chainID: BigInteger): Boolean {
        Log.i(logTag, "sendTakerInformationMessage: checking if message should be sent for $swapID")
        val swap = swapTruthSource.swaps[swapID]
        if (swap == null) {
            Log.i(logTag, "sendTakerInformationMessage: could not find $swapID in swapTruthSource")
            return false
        }
        if (swap.chainID != chainID) {
            throw SwapServiceException("Passed chain ID $chainID does not match that of swap ${swap.id}: " +
                    "${swap.chainID}")
        }
        if (swap.role != SwapRole.TAKER_AND_BUYER && swap.role != SwapRole.TAKER_AND_SELLER) {
            Log.i(logTag, "sendTakerInformationMessage: user is not taker in $swapID")
            return false
        }
        Log.i(logTag, "sendTakerInformationMessage: user is taker in ${swapID}, sending message")
        val encoder = Base64.getEncoder()
        val swapIDString = encoder.encodeToString(swapID.asByteArray())
        databaseService.updateSwapState(
            swapID = swapIDString,
            chainID = chainID.toString(),
            state = SwapState.AWAITING_TAKER_INFORMATION.asString
        )
        withContext(Dispatchers.Main) {
            swap.state.value = SwapState.AWAITING_TAKER_INFORMATION
        }
        /*
        The user of this interface has taken the swap. Since taking a swap is not allowed unless we have a copy of the
        maker's public key, we should have said public key in storage.
         */
        val makerPublicKey = keyManagerService.getPublicKey(swap.makerInterfaceID)
            ?: throw SwapServiceException("Could not find maker's public key for $swapID")
        /*
        Since the user of this interface has taken the swap, we should have a key pair for the swap in persistent
        storage.
         */
        val takerKeyPair = keyManagerService.getKeyPair(swap.takerInterfaceID)
            ?: throw SwapServiceException("Could not find taker's (user's) key pair for $swapID")
        if (swap.takerPrivateSettlementMethodData == null) {
            Log.w(logTag, "sendTakerInformationMessage: taker info is null for $swapID")
        }
        Log.i(logTag, "sendTakerInformationMessage: sending for $swapID")
        p2pService.sendTakerInformation(
            makerPublicKey = makerPublicKey,
            takerKeyPair = takerKeyPair,
            swapID = swapID,
            settlementMethodDetails = swap.takerPrivateSettlementMethodData
        )
        Log.i(logTag, "sendTakerInformationMessage: sent for $swapID")
        databaseService.updateSwapState(
            swapID = swapIDString,
            chainID = chainID.toString(),
            state = SwapState.AWAITING_MAKER_INFORMATION.asString
        )
        withContext(Dispatchers.Main) {
            swap.state.value = SwapState.AWAITING_MAKER_INFORMATION
        }
        // We have sent a taker info message for this swap, so we return true
        return true
    }

    /**
     * Attempts to fill a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap),
     * using the process described in the
     * [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     *
     * On the IO coroutine dispatcher, this ensures that the user is the maker and stablecoin seller of [swapToFill],
     * and that [swapToFill] can actually be filled. Then this approves token transfer for [swapToFill]'s
     * [Swap.takenSwapAmount] to the
     * [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, calls the
     * CommutoSwap contract's [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap)
     * function (via [blockchainService]), persistently updates the state of [swapToFill] to
     * [SwapState.FILL_SWAP_TRANSACTION_BROADCAST], and sets [swapToFill]'s [Swap.requiresFill] property to false.
     * Finally, on the main coroutine dispatcher, this updates [swapToFill]'s [Swap.state] value to
     * [SwapState.FILL_SWAP_TRANSACTION_BROADCAST].
     *
     * @param swapToFill The [Swap] that this function will fill.
     * @param afterPossibilityCheck A lambda that will be executed after this has ensured that the swap can be filled.
     * @param afterTransferApproval A lambda that will be executed after the token transfer approval to the
     * [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
     *
     * @throws SwapServiceException if [swapToFill] is not a maker-as-seller swap and the user is not the maker, or if
     * the [swapToFill]'s state is not `awaitingFilling`
     */
    suspend fun fillSwap(
        swapToFill: Swap,
        afterPossibilityCheck: (suspend () -> Unit)? = null,
        afterTransferApproval: (suspend () -> Unit)? = null,
    ) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "fillSwap: checking that ${swapToFill.id} can be filled")
            try {
                if (swapToFill.role != SwapRole.MAKER_AND_SELLER) {
                    throw SwapServiceException("Only Maker-As-Seller swaps can be filled")
                }
                if (swapToFill.state.value != SwapState.AWAITING_FILLING) {
                    throw SwapServiceException("This Swap cannot currently be filled")
                }
                afterPossibilityCheck?.invoke()
                Log.i(logTag, "fillSwap: authorizing transfer for ${swapToFill.id}. Amount: " +
                        "${swapToFill.takenSwapAmount}")
                blockchainService.approveTokenTransferAsync(
                    tokenAddress = swapToFill.stablecoin,
                    destinationAddress = blockchainService.getCommutoSwapAddress(),
                    amount = swapToFill.takenSwapAmount,
                ).await()
                Log.i(logTag, "fillSwap: filling ${swapToFill.id}")
                blockchainService.fillSwapAsync(
                    id = swapToFill.id
                ).await()
                afterTransferApproval?.invoke()
                Log.i(logTag, "fillSwap: filled ${swapToFill.id}")
                val encoder = Base64.getEncoder()
                val swapIDB64String = encoder.encodeToString(swapToFill.id.asByteArray())
                databaseService.updateSwapState(
                    swapID = swapIDB64String,
                    chainID = swapToFill.chainID.toString(),
                    state = SwapState.FILL_SWAP_TRANSACTION_BROADCAST.asString,
                )
                databaseService.updateSwapRequiresFill(
                    swapID = swapIDB64String,
                    chainID = swapToFill.chainID.toString(),
                    requiresFill = false,
                )
                // This is not a MutableState property, so we can upgrade it from a background thread
                swapToFill.requiresFill = false
                withContext(Dispatchers.Main) {
                    swapToFill.state.value = SwapState.FILL_SWAP_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "fillSwap: encountered exception during call for ${swapToFill.id}", exception)
                throw exception
            }
        }
    }

    /**
     * Reports that payment has been sent to the seller in a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the
     * [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     *
     * On the IO coroutine dispatcher, this ensures that the user is the buyer in [swap] and that reporting payment
     * sending is currently possible for [swap]. Then this calls the CommutoSwap contract's
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent)
     * function (via [blockchainService]), and persistently updates the state of the swap to
     * [SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST]. Finally, on the main coroutine dispatcher, this updates
     * the state of [swap] to [SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST].
     *
     * @param swap The [Swap] for which this function will report the sending of payment.
     * @param afterPossibilityCheck A lambda that will be executed after this has ensured that payment sending can be
     * reported for the swap.
     *
     * @throws SwapServiceException if the user is not the buyer for [swap], or if [swap]'s state is not
     * [SwapState.AWAITING_PAYMENT_SENT].
     */
    suspend fun reportPaymentSent(
        swap: Swap,
        afterPossibilityCheck: (suspend () -> Unit)? = null,
    ) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "reportPaymentSent: checking reporting is possible for ${swap.id}")
            try {
                // Ensure that the user is the buyer for the swap
                if (swap.role != SwapRole.MAKER_AND_BUYER && swap.role != SwapRole.TAKER_AND_BUYER) {
                    throw SwapServiceException("Only the Buyer can report sending payment")
                }
                // Ensure that this swap is awaiting reporting of payment sent
                if (swap.state.value != SwapState.AWAITING_PAYMENT_SENT) {
                    throw SwapServiceException("Payment sending cannot currently be reported for this swap")
                }
                afterPossibilityCheck?.invoke()
                Log.i(logTag, "reportPaymentSent: reporting ${swap.id}")
                blockchainService.reportPaymentSentAsync(id = swap.id).await()
                Log.i(logTag, "reportPaymentSent: reported for ${swap.id}")
                databaseService.updateSwapState(
                    swapID = Base64.getEncoder().encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST.asString,
                )
                withContext(Dispatchers.Main) {
                    swap.state.value = SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "reportPaymentSent: encountered exception during call for ${swap.id}", exception)
                throw exception
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] that will call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface
     * is the buyer.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForReportingPaymentSent], and then
     * [BlockchainService.createReportPaymentSentTransaction], passing the [Swap.id] and [Swap.chainID] properties of
     * [Swap], and then returns the result.
     *
     * @param swap The [Swap] for which
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be
     * called.
     *
     * @return A [RawTransaction] capable of calling
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for
     * [swap].
     */
    suspend fun createReportPaymentSentTransaction(swap: Swap): RawTransaction {
        return withContext(Dispatchers.IO) {
            Log.i(logTag, "createReportPaymentSentTransaction: creating for ${swap.id}")
            validateSwapForReportingPaymentSent(swap = swap)
            blockchainService.createReportPaymentSentTransaction(swapID = swap.id, chainID = swap.chainID)
        }
    }

    /**
     * Attempts to call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) in which the user of this interface is
     * the buyer.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForReportingPaymentSent], and ensures that
     * [reportPaymentSentTransaction] is not `null`. Then it signs [reportPaymentSentTransaction], creates a
     * [BlockchainTransaction] to wrap it, determines the transaction hash, persistently stores the transaction hash and
     * persistently updates the [Swap.reportingPaymentSentState] of [swap] to
     * [ReportingPaymentSentState.SENDING_TRANSACTION]. Then, on the main coroutine dispatcher, this stores the
     * transaction hash in [swap] and sets [swap]'s [Swap.reportingPaymentSentState] property to
     * [ReportingPaymentSentState.SENDING_TRANSACTION]. Then, on the IO coroutine dispatcher, it sends the
     * [BlockchainTransaction]-wrapped [reportPaymentSentTransaction] to the blockchain. Once a response is received,
     * this persistently updates the [Swap.reportingPaymentSentState] of [swap] to
     * [ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION] and persistently updates the [Swap.state] property
     * of [swap] to [SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST]. Then, on the main coroutine dispatcher, this
     * sets the value of [swap]'s [Swap.reportingPaymentSentState] to
     * [ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION] and the value of [swap]'s [Swap.state] to
     * [SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST].
     *
     * @param swap The [Swap] for which
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be
     * called.
     * @param reportPaymentSentTransaction An optional [RawTransaction] that can call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for
     * [swap].
     *
     * @throws [SwapServiceException] if [reportPaymentSentTransaction] is `null`.
     */
    suspend fun reportPaymentSent(swap: Swap, reportPaymentSentTransaction: RawTransaction?) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "reportPaymentSent: checking reporting is possible for ${swap.id}")
            validateSwapForReportingPaymentSent(swap = swap)
            try {
                if (reportPaymentSentTransaction == null) {
                    throw SwapServiceException(message = "Transaction was null during reportPaymentSent call for " +
                            swap.id)
                }
                Log.i(logTag, "reportPaymentSent: signing transaction for ${swap.id}")
                val signedTransactionData = blockchainService.signTransaction(
                    transaction = reportPaymentSentTransaction,
                    chainID = swap.chainID
                )
                val signedTransactionHex = Numeric.toHexString(signedTransactionData)
                val transactionHash = Hash.sha3(signedTransactionHex)
                val blockchainTransactionForReportingPaymentSent = BlockchainTransaction(
                    transaction = reportPaymentSentTransaction,
                    transactionHash = transactionHash,
                    latestBlockNumberAtCreation = blockchainService.newestBlockNum,
                    type = BlockchainTransactionType.REPORT_PAYMENT_SENT
                )
                val dateString = DateFormatter.createDateString(blockchainTransactionForReportingPaymentSent
                    .timeOfCreation)
                Log.i(logTag, "reportPaymentSent: persistently storing report payment sent data for ${swap.id}, " +
                        "including tx hash ${blockchainTransactionForReportingPaymentSent.transactionHash}")
                val encoder = Base64.getEncoder()
                databaseService.updateReportPaymentSentData(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    transactionHash = blockchainTransactionForReportingPaymentSent.transactionHash,
                    creationTime = dateString,
                    blockNumber = blockchainTransactionForReportingPaymentSent.latestBlockNumberAtCreation.toLong()
                )
                Log.i(logTag, "reportPaymentSent: persistently updating reportingPaymentSentState for ${swap.id} to " +
                        "sendingTransaction")
                databaseService.updateReportPaymentSentState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentSentState.SENDING_TRANSACTION.asString
                )
                Log.i(logTag, "reportPaymentSent: updating reportingPaymentSentState for ${swap.id} to " +
                        "sendingTransaction and storing tx hash ${blockchainTransactionForReportingPaymentSent
                            .transactionHash} in swap")
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentSentState.value = ReportingPaymentSentState.SENDING_TRANSACTION
                    swap.reportPaymentSentTransaction = blockchainTransactionForReportingPaymentSent
                }
                Log.i(logTag, "reportPaymentSent: sending $transactionHash for ${swap.id}")
                blockchainService.sendTransaction(
                    transaction = blockchainTransactionForReportingPaymentSent,
                    signedRawTransactionDataAsHex = signedTransactionHex,
                    chainID = swap.chainID
                )
                Log.i(logTag, "reportPaymentSent: persistently updating reportingPaymentSentState of ${swap.id} " +
                        "to awaitingTransactionConfirmation")
                databaseService.updateReportPaymentSentState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION.asString
                )
                Log.i(logTag, "reportPaymentSent: persistently updating state of ${swap.id} to " +
                        "reportPaymentSentTransactionBroadcast")
                databaseService.updateSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST.asString
                )
                Log.i(logTag, "reportPaymentSent: updating reportingPaymentSentState for ${swap.id} to " +
                        "awaitingTransactionConfirmation and state to reportPaymentSentTransactionBroadcast")
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentSentState.value = ReportingPaymentSentState.AWAITING_TRANSACTION_CONFIRMATION
                    swap.state.value = SwapState.REPORT_PAYMENT_SENT_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "reportPaymentSent: encountered exception while reporting for ${swap.id}, setting " +
                        "reportingPaymentSentState to exception", exception)
                val encoder = Base64.getEncoder()
                databaseService.updateReportPaymentSentState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentSentState.EXCEPTION.asString
                )
                swap.reportingPaymentSentException = exception
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentSentState.value = ReportingPaymentSentState.EXCEPTION
                }
                throw exception
            }
        }
    }

    /**
     * Reports that payment has been received by the seller in a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the
     * [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     *
     * On the IO coroutine dispatcher, this ensures that the user is the seller in [swap] and that reporting payment
     * receipt is currently possible for [swap]. Then this calls the CommutoSwap contract's
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * function (via [blockchainService]), and persistently updates the state of the swap to
     * [SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST]. Finally, on the main coroutine dispatcher, this updates
     * the state of [swap] to [SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST].
     *
     * @param swap The [Swap] for which this function will report the receipt of payment.
     * @param afterPossibilityCheck A lambda that will be executed after this has ensured that payment receipt can be
     * reported for the swap.
     *
     * @throws SwapServiceException if the user is not the seller for [swap], or if [swap]'s state is not
     * [SwapState.AWAITING_PAYMENT_RECEIVED].
     */
    suspend fun reportPaymentReceived(
        swap: Swap,
        afterPossibilityCheck: (suspend () -> Unit)? = null,
    ) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "reportPaymentReceived: checking reporting is possible for ${swap.id}")
            try {
                // Ensure that the user is the seller for the swap
                if (swap.role != SwapRole.MAKER_AND_SELLER && swap.role != SwapRole.TAKER_AND_SELLER) {
                    throw SwapServiceException("Only the Seller can report receiving payment")
                }
                // Ensure that this swap is awaiting reporting of payment received
                if (swap.state.value != SwapState.AWAITING_PAYMENT_RECEIVED) {
                    throw SwapServiceException("Receiving payment cannot currently be reported for this swap")
                }
                afterPossibilityCheck?.invoke()
                Log.i(logTag, "reportPaymentReceived: reporting ${swap.id}")
                blockchainService.reportPaymentReceivedAsync(id = swap.id).await()
                Log.i(logTag, "reportPaymentReceived: reported for ${swap.id}")
                databaseService.updateSwapState(
                    swapID = Base64.getEncoder().encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST.asString,
                )
                withContext(Dispatchers.Main) {
                    swap.state.value = SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "reportPaymentReceived: encountered exception during call for ${swap.id}", exception)
                throw exception
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] that will call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this
     * interface is the buyer.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForReportingPaymentReceived], and then
     * [BlockchainService.createReportPaymentReceivedTransaction], passing the [Swap.id] and [Swap.chainID] properties
     * of [swap], and returns the result.
     *
     * @param swap The [Swap] for which
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * will be called.
     *
     * @return A [RawTransaction] capable of calling
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for [swap].
     */
    suspend fun createReportPaymentReceivedTransaction(swap: Swap): RawTransaction {
        return withContext(Dispatchers.IO) {
            Log.i(logTag, "createReportPaymentReceivedTransaction: creating for ${swap.id}")
            validateSwapForReportingPaymentReceived(swap = swap)
            blockchainService.createReportPaymentReceivedTransaction(swapID = swap.id, chainID = swap.chainID)
        }
    }

    /**
     * Attempts to call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) in which the user of this
     * interface is the seller.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForReportingPaymentReceived], and ensures that
     * [reportPaymentReceivedTransaction] is not `null`. Then it signs [reportPaymentReceivedTransaction], creates a
     * [BlockchainTransaction] to wrap it, determines the transaction hash, persistently stores the transaction hash and
     * persistently updates the [Swap.reportingPaymentReceivedState] of [swap] to
     * [ReportingPaymentReceivedState.SENDING_TRANSACTION]. Then, on the main coroutine dispatcher, this stores the
     * transaction hash in [swap] and sets [swap]'s [Swap.reportingPaymentReceivedState] property to
     * [ReportingPaymentReceivedState.SENDING_TRANSACTION]. Then, on the IO coroutine dispatcher, it sends the
     * [BlockchainTransaction]-wrapped [reportPaymentReceivedTransaction] to the blockchain. Once a response is
     * received, this persistently updates the [Swap.reportingPaymentReceivedState] of [swap] to
     * [ReportingPaymentReceivedState.AWAITING_TRANSACTION_CONFIRMATION] and persistently updates the [Swap.state]
     * property of [swap] to [SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST]. Then, on the main coroutine
     * dispatcher, this sets the value of [swap]'s [Swap.reportingPaymentReceivedState] to
     * [ReportingPaymentReceivedState.AWAITING_TRANSACTION_CONFIRMATION] and the value of [swap]'s [Swap.state] to
     * [SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST].
     *
     * @param swap The [Swap] for which
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * will be called.
     * @param reportPaymentReceivedTransaction An optional [RawTransaction] that can call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for [swap].
     *
     * @throws [SwapServiceException] if [reportPaymentReceivedTransaction] is `null`.
     */
    suspend fun reportPaymentReceived(swap: Swap, reportPaymentReceivedTransaction: RawTransaction?) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "reportPaymentReceived: checking reporting is possible for ${swap.id}")
            validateSwapForReportingPaymentReceived(swap = swap)
            try {
                if (reportPaymentReceivedTransaction == null) {
                    throw SwapServiceException(message = "Transaction was null during reportPaymentReceived call for " +
                            swap.id)
                }
                Log.i(logTag, "reportPaymentReceived: signing transaction for ${swap.id}")
                val signedTransactionData = blockchainService.signTransaction(
                    transaction = reportPaymentReceivedTransaction,
                    chainID = swap.chainID
                )
                val signedTransactionHex = Numeric.toHexString(signedTransactionData)
                val transactionHash = Hash.sha3(signedTransactionHex)
                val blockchainTransactionForReportingPaymentReceived = BlockchainTransaction(
                    transaction = reportPaymentReceivedTransaction,
                    transactionHash = transactionHash,
                    latestBlockNumberAtCreation = blockchainService.newestBlockNum,
                    type = BlockchainTransactionType.REPORT_PAYMENT_RECEIVED
                )
                val dateString = DateFormatter.createDateString(blockchainTransactionForReportingPaymentReceived
                    .timeOfCreation)
                Log.i(logTag, "reportPaymentReceived: persistently storing report payment received data for ${swap
                    .id}, including tx hash ${blockchainTransactionForReportingPaymentReceived.transactionHash}")
                val encoder = Base64.getEncoder()
                databaseService.updateReportPaymentReceivedData(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    transactionHash = blockchainTransactionForReportingPaymentReceived.transactionHash,
                    creationTime = dateString,
                    blockNumber = blockchainTransactionForReportingPaymentReceived.latestBlockNumberAtCreation.toLong()
                )
                Log.i(logTag, "reportPaymentReceived: persistently updating reportingPaymentReceivedState for " +
                        "${swap.id} to sendingTransaction")
                databaseService.updateReportPaymentReceivedState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentReceivedState.SENDING_TRANSACTION.asString
                )
                Log.i(logTag, "reportPaymentReceived: updating reportingPaymentReceivedState for ${swap.id} to " +
                        "sendingTransaction and storing tx hash ${blockchainTransactionForReportingPaymentReceived
                            .transactionHash} in swap")
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.SENDING_TRANSACTION
                    swap.reportPaymentReceivedTransaction = blockchainTransactionForReportingPaymentReceived
                }
                Log.i(logTag, "reportPaymentReceived: sending $transactionHash for ${swap.id}")
                blockchainService.sendTransaction(
                    transaction = blockchainTransactionForReportingPaymentReceived,
                    signedRawTransactionDataAsHex = signedTransactionHex,
                    chainID = swap.chainID
                )
                Log.i(logTag, "reportPaymentReceived: persistently updating reportingPaymentReceivedState of ${swap
                    .id} to awaitingTransactionConfirmation")
                databaseService.updateReportPaymentReceivedState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentReceivedState.AWAITING_TRANSACTION_CONFIRMATION.asString
                )
                Log.i(logTag, "reportPaymentReceived: persistently updating state of ${swap.id} to " +
                        "reportPaymentReceivedTransactionBroadcast")
                databaseService.updateSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST.asString
                )
                Log.i(logTag, "reportPaymentReceived: updating reportingPaymentReceivedState for ${swap.id} to " +
                        "awaitingTransactionConfirmation and state to reportPaymentReceivedTransactionBroadcast")
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState
                        .AWAITING_TRANSACTION_CONFIRMATION
                    swap.state.value = SwapState.REPORT_PAYMENT_RECEIVED_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "reportPaymentReceived: encountered exception while reporting for ${swap.id}, " +
                        "setting reportingPaymentReceivedState to exception", exception)
                val encoder = Base64.getEncoder()
                databaseService.updateReportPaymentReceivedState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ReportingPaymentReceivedState.EXCEPTION.asString
                )
                swap.reportingPaymentReceivedException = exception
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.EXCEPTION
                }
                throw exception
            }
        }
    }

    /**
     * Attempts to close a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the
     * [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     *
     * On the IO coroutine dispatcher, this ensures that [swap] can be closed. Then this calls the CommutoSwap
     * contract's [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) function (via
     * [blockchainService]), and persistently updates the state of the swap to
     * [SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST]. Finally, this does the same to [swap], updating its [Swap.state] on
     * the main coroutine dispatcher.
     *
     * @param swap The [Swap] this function will close.
     * @param afterPossibilityCheck A lambda that will be executed after this has ensured [swap] can be closed.
     *
     * @throws SwapServiceException if [swap]'s state is not [SwapState.AWAITING_CLOSING].
     */
    suspend fun  closeSwap(
        swap: Swap,
        afterPossibilityCheck: (suspend () -> Unit)? = null,
    ) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "closeSwap: checking if ${swap.id} can be closed")
            try {
                // Ensure that this swap is awaiting closing
                if (swap.state.value != SwapState.AWAITING_CLOSING) {
                    throw SwapServiceException("This swap cannot currently be closed")
                }
                afterPossibilityCheck?.invoke()
                Log.i(logTag, "closeSwap: closing ${swap.id}")
                blockchainService.closeSwapAsync(id = swap.id).await()
                Log.i(logTag, "closeSwap: closed ${swap.id}")
                databaseService.updateSwapState(
                    swapID = Base64.getEncoder().encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST.asString,
                )
                withContext(Dispatchers.Main) {
                    swap.state.value = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "reportPaymentReceived: encountered exception during call for ${swap.id}", exception)
                throw exception
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] that will call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) involving the user of this
     * interface.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForClosing], and then calls
     * [BlockchainService.createCloseSwapTransaction], passing the [Swap.id] and [Swap.chainID] properties of [swap],
     * and returns the result.
     *
     * @param swap The [Swap] for which
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
     *
     * @return A [RawTransaction] capable of calling
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for [swap].
     */
    suspend fun createCloseSwapTransaction(swap: Swap): RawTransaction {
        return withContext(Dispatchers.IO) {
            Log.i(logTag, "createCloseSwapTransaction: creating for ${swap.id}")
            validateSwapForClosing(swap = swap)
            blockchainService.createCloseSwapTransaction(swapID = swap.id, chainID = swap.chainID)
        }
    }

    /**
     * Attempts to call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) involving the user of this interface.
     *
     * On the IO coroutine dispatcher, this calls [validateSwapForClosing] and ensures that [closeSwapTransaction] is
     * not `null`. Then it signs [closeSwapTransaction], creates a [BlockchainTransaction] to wrap it, determines the
     * transaction hash, persistently stores the transaction hash and persistently updates the [Swap.closingSwapState]
     * of [swap] to [ClosingSwapState.SENDING_TRANSACTION]. Then, on the main coroutine dispatcher, this stores the
     * transaction hash in [swap] and sets [swap]'s [Swap.closingSwapState] property to
     * [ClosingSwapState.SENDING_TRANSACTION]. Then, on the IO coroutine dispatcher, it sends the
     * [BlockchainTransaction]-wrapped [closeSwapTransaction] to the blockchain. Once a response is received, this
     * persistently updates the [Swap.closingSwapState] of [swap] to
     * [ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION] and persistently updates the [Swap.state] property of [swap]
     * to [SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST]. Then, on the main coroutine dispatcher, this sets the value of
     * [swap]'s [Swap.closingSwapState] property to [ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION] and the value
     * of [swap]'s [Swap.state] to [SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST].
     *
     * @param swap The [Swap] for which
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * will be called.
     * @param closeSwapTransaction An optional [RawTransaction] that can call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * for [swap].
     *
     * @throws [SwapServiceException] if [closeSwapTransaction] is `null`.
     */
    suspend fun closeSwap(swap: Swap, closeSwapTransaction: RawTransaction?) {
        withContext(Dispatchers.IO) {
            Log.i(logTag, "closeSwap: checking closing is possible for ${swap.id}")
            validateSwapForClosing(swap = swap)
            try {
                if (closeSwapTransaction == null) {
                    throw SwapServiceException(message = "Transaction was null during closeSwap call for ${swap.id}")
                }
                Log.i(logTag, "closeSwap: signing transaction for ${swap.id}")
                val signedTransactionData = blockchainService.signTransaction(
                    transaction = closeSwapTransaction,
                    chainID = swap.chainID
                )
                val signedTransactionHex = Numeric.toHexString(signedTransactionData)
                val transactionHash = Hash.sha3(signedTransactionHex)
                val blockchainTransactionForClosingSwap = BlockchainTransaction(
                    transaction = closeSwapTransaction,
                    transactionHash = transactionHash,
                    latestBlockNumberAtCreation = blockchainService.newestBlockNum,
                    type = BlockchainTransactionType.CLOSE_SWAP
                )
                val dateString = DateFormatter.createDateString(blockchainTransactionForClosingSwap
                    .timeOfCreation)
                Log.i(logTag, "closeSwap: persistently storing close swap data for ${swap.id}, including tx " +
                        "hash ${blockchainTransactionForClosingSwap.transactionHash}")
                val encoder = Base64.getEncoder()
                databaseService.updateCloseSwapData(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    transactionHash = blockchainTransactionForClosingSwap.transactionHash,
                    creationTime = dateString,
                    blockNumber = blockchainTransactionForClosingSwap.latestBlockNumberAtCreation.toLong()
                )
                Log.i(logTag, "closeSwap: persistently updating closeSwapState for ${swap.id} to " +
                        ClosingSwapState.SENDING_TRANSACTION.asString
                )
                databaseService.updateCloseSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ClosingSwapState.SENDING_TRANSACTION.asString
                )
                Log.i(logTag, "closeSwap: updating closeSwapState for ${swap.id} to sendingTransaction and " +
                        "storing tx hash ${blockchainTransactionForClosingSwap.transactionHash} in swap")
                withContext(Dispatchers.Main) {
                    swap.closingSwapState.value = ClosingSwapState.SENDING_TRANSACTION
                    swap.closeSwapTransaction = blockchainTransactionForClosingSwap
                }
                Log.i(logTag, "closeSwap: sending $transactionHash for ${swap.id}")
                blockchainService.sendTransaction(
                    transaction = blockchainTransactionForClosingSwap,
                    signedRawTransactionDataAsHex = signedTransactionHex,
                    chainID = swap.chainID
                )
                Log.i(logTag, "closeSwap: persistently updating closeSwapState of ${swap.id} to " +
                        ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION.asString
                )
                databaseService.updateCloseSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION.asString
                )
                Log.i(logTag, "closeSwap: persistently updating state of ${swap.id} to " +
                        SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST.asString
                )
                databaseService.updateSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST.asString
                )
                Log.i(logTag, "closeSwap: updating closeSwapState for ${swap.id} to " +
                        "${ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION} and state to " +
                        "${SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST}")
                withContext(Dispatchers.Main) {
                    swap.closingSwapState.value = ClosingSwapState.AWAITING_TRANSACTION_CONFIRMATION
                    swap.state.value = SwapState.CLOSE_SWAP_TRANSACTION_BROADCAST
                }
            } catch (exception: Exception) {
                Log.e(logTag, "closeSwap: encountered exception while closing ${swap.id}, setting " +
                        "closingSwapState to exception", exception)
                val encoder = Base64.getEncoder()
                databaseService.updateCloseSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ClosingSwapState.EXCEPTION.asString
                )
                swap.closingSwapException = exception
                withContext(Dispatchers.Main) {
                    swap.closingSwapState.value = ClosingSwapState.EXCEPTION
                }
                throw exception
            }
        }
    }

    /**
     * The function called by [BlockchainService] in order to notify [SwapService] that a monitored swap-related
     * [BlockchainTransaction] has failed (either has been confirmed and failed, or has been dropped.)
     *
     * If [transaction] is of type [BlockchainTransactionType.REPORT_PAYMENT_SENT], then this finds the swap with the
     * corresponding reporting payment sent transaction hash, persistently updates its reporting payment sent state to
     * [ReportingPaymentSentState.EXCEPTION]` and its state to [SwapState.AWAITING_PAYMENT_SENT], and on the main
     * coroutine dispatcher sets its [Swap.reportingPaymentSentException] to [exception], updates its
     * [Swap.reportingPaymentSentState] property to [ReportingPaymentSentState.EXCEPTION], and updates its [Swap.state]
     * property to [SwapState.AWAITING_PAYMENT_SENT].
     *
     * @param transaction The [BlockchainTransaction] wrapping the on-chain transaction that has failed.
     * @param exception A [BlockchainTransactionException] describing why the on-chain transaction has failed.
     *
     * @throws [SwapServiceException] if this is passed an offer-related [BlockchainTransaction].
     */
    override suspend fun handleFailedTransaction(
        transaction: BlockchainTransaction,
        exception: BlockchainTransactionException
    ) {
        Log.w(logTag, "handleFailedTransaction: handling ${transaction.transactionHash} of type ${transaction.type
            .asString} with exception ${exception.message}")
        val encoder = Base64.getEncoder()
        when (transaction.type) {
            BlockchainTransactionType.APPROVE_TOKEN_TRANSFER_TO_OPEN_OFFER, BlockchainTransactionType.OPEN_OFFER,
            BlockchainTransactionType.CANCEL_OFFER, BlockchainTransactionType.EDIT_OFFER -> {
                throw SwapServiceException(message = "handleFailedTransaction: received an offer-related transaction " +
                        transaction.transactionHash
                )
            }
            BlockchainTransactionType.REPORT_PAYMENT_SENT -> {
                val swap = swapTruthSource.swaps.firstNotNullOfOrNull { uuidSwapEntry ->
                    if (uuidSwapEntry.value.reportPaymentSentTransaction?.transactionHash
                            .equals(transaction.transactionHash)) {
                        uuidSwapEntry.value
                    } else {
                        null
                    }
                }
                if (swap != null) {
                    Log.w(logTag, "handleFailedTransaction: found swap ${swap.id} on ${swap.chainID} with " +
                            "report payment sent transaction ${transaction.transactionHash}, updating " +
                            "reportingPaymentSentState to EXCEPTION and state to AWAITING_PAYMENT_SENT in persistent " +
                            "storage")
                    databaseService.updateReportPaymentSentState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = ReportingPaymentSentState.EXCEPTION.asString,
                    )
                    databaseService.updateSwapState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = SwapState.AWAITING_PAYMENT_SENT.asString
                    )
                    Log.w(logTag, "handleFailedTransaction: setting reportingPaymentSentException, updating " +
                            "reportingPaymentSentState to EXCEPTION and state to AWAITING_PAYMENT_SENT for ${swap.id}")
                    withContext(Dispatchers.Main) {
                        swap.reportingPaymentSentException = exception
                        swap.reportingPaymentSentState.value = ReportingPaymentSentState.EXCEPTION
                        swap.state.value = SwapState.AWAITING_PAYMENT_SENT
                    }
                } else {
                    Log.w(logTag, "handleFailedTransaction: swap with report payment sent transaction " +
                            "${transaction.transactionHash} not found in swapTruthSource")
                }
            }
            BlockchainTransactionType.REPORT_PAYMENT_RECEIVED -> {
                val swap = swapTruthSource.swaps.firstNotNullOfOrNull { uuidSwapEntry ->
                    if (uuidSwapEntry.value.reportPaymentReceivedTransaction?.transactionHash
                            .equals(transaction.transactionHash)) {
                        uuidSwapEntry.value
                    } else {
                        null
                    }
                }
                if (swap != null) {
                    Log.w(logTag, "handleFailedTransaction: found swap ${swap.id} on ${swap.chainID} with " +
                            "report payment received transaction ${transaction.transactionHash}, updating " +
                            "reportingPaymentReceivedState to EXCEPTION and state to AWAITING_PAYMENT_RECEIVED in " +
                            "persistent storage")
                    databaseService.updateReportPaymentReceivedState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = ReportingPaymentReceivedState.EXCEPTION.asString,
                    )
                    databaseService.updateSwapState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = SwapState.AWAITING_PAYMENT_RECEIVED.asString
                    )
                    Log.w(logTag, "handleFailedTransaction: setting reportingPaymentReceivedException, updating " +
                            "reportingPaymentReceivedState to EXCEPTION and state to AWAITING_PAYMENT_RECEIVED for " +
                            "${swap.id}")
                    withContext(Dispatchers.Main) {
                        swap.reportingPaymentReceivedException = exception
                        swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.EXCEPTION
                        swap.state.value = SwapState.AWAITING_PAYMENT_RECEIVED
                    }
                } else {
                    Log.w(logTag, "handleFailedTransaction: swap with report payment received transaction " +
                            "${transaction.transactionHash} not found in swapTruthSource")
                }
            }
            BlockchainTransactionType.CLOSE_SWAP -> {
                val swap = swapTruthSource.swaps.firstNotNullOfOrNull { uuidSwapEntry ->
                    if (uuidSwapEntry.value.closeSwapTransaction?.transactionHash.equals(transaction.transactionHash)) {
                        uuidSwapEntry.value
                    } else {
                        null
                    }
                }
                if (swap != null) {
                    Log.w(logTag, "handleFailedTransaction: found swap ${swap.id} on ${swap.chainID} with close " +
                            "swap transaction ${transaction.transactionHash}, updating closeSwapState to EXCEPTION " +
                            "and state to AWAITING_CLOSING in persistent storage")
                    databaseService.updateCloseSwapState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = ClosingSwapState.EXCEPTION.asString,
                    )
                    databaseService.updateSwapState(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        state = SwapState.AWAITING_CLOSING.asString
                    )
                    Log.w(logTag, "handleFailedTransaction: setting closingSwapException, updating " +
                            "closingSwapState to EXCEPTION and state to AWAITING_CLOSING for ${swap.id}")
                    withContext(Dispatchers.Main) {
                        swap.closingSwapException = exception
                        swap.closingSwapState.value = ClosingSwapState.EXCEPTION
                        swap.state.value = SwapState.AWAITING_CLOSING
                    }
                } else {
                    Log.w(logTag, "handleFailedTransaction: swap with close swap transaction ${transaction
                        .transactionHash} not found in swapTruthSource")
                }
            }
        }
    }

    /**
     * Gets the on-chain [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) corresponding to
     * [takenOffer], determines which one of [takenOffer]'s settlement methods the offer taker has selected, gets the
     * user's (maker's) private settlement method data for this settlement method, and creates and persistently stores a
     * new [Swap] with state [SwapState.AWAITING_TAKER_INFORMATION] using the on-chain swap and the user's (maker's)
     * private settlement method data, and maps [takenOffer]'s ID to the new [Swap] on the main coroutine dispatcher.
     * This should only be called for swaps made by the user of this interface.
     *
     * @param takenOffer The [Offer] made by the user of this interface that has been taken and now corresponds to a
     * swap.
     */
    override suspend fun handleNewSwap(takenOffer: Offer) {
        Log.i(logTag, "handleNewSwap: getting on-chain struct for ${takenOffer.id}")
        val swapOnChain = blockchainService.getSwap(id = takenOffer.id)
        if (swapOnChain == null) {
            Log.e(logTag, "handleNewSwap: could not find ${takenOffer.id} on chain, throwing exception")
            throw SwapServiceException("Could not find ${takenOffer.id} on chain")
        }
        val direction: OfferDirection = when (swapOnChain.direction) {
            BigInteger.ZERO -> OfferDirection.BUY
            BigInteger.ONE -> OfferDirection.SELL
            else -> throw SwapServiceException("Swap ${takenOffer.id} has invalid direction: ${swapOnChain.direction}")
        }
        val swapRole = when (direction) {
            OfferDirection.BUY -> SwapRole.MAKER_AND_BUYER
            OfferDirection.SELL -> SwapRole.MAKER_AND_SELLER
        }
        val newSwap = Swap(
            isCreated = swapOnChain.isCreated,
            requiresFill = swapOnChain.requiresFill,
            id = takenOffer.id,
            maker = swapOnChain.maker,
            makerInterfaceID = swapOnChain.makerInterfaceID,
            taker = swapOnChain.taker,
            takerInterfaceID = swapOnChain.takerInterfaceID,
            stablecoin = swapOnChain.stablecoin,
            amountLowerBound = swapOnChain.amountLowerBound,
            amountUpperBound = swapOnChain.amountUpperBound,
            securityDepositAmount = swapOnChain.securityDepositAmount,
            takenSwapAmount = swapOnChain.takenSwapAmount,
            serviceFeeAmount = swapOnChain.serviceFeeAmount,
            serviceFeeRate = swapOnChain.serviceFeeRate,
            direction = direction,
            onChainSettlementMethod = swapOnChain.settlementMethod,
            protocolVersion = swapOnChain.protocolVersion,
            isPaymentSent = swapOnChain.isPaymentSent,
            isPaymentReceived = swapOnChain.isPaymentReceived,
            hasBuyerClosed = swapOnChain.hasBuyerClosed,
            hasSellerClosed = swapOnChain.hasSellerClosed,
            onChainDisputeRaiser = swapOnChain.disputeRaiser,
            chainID = swapOnChain.chainID,
            state = SwapState.AWAITING_TAKER_INFORMATION,
            role = swapRole,
        )
        val deserializedSelectedSettlementMethod = try {
            Json.decodeFromString<SettlementMethod>(swapOnChain.settlementMethod.decodeToString())
        } catch (exception: Exception) {
            null
        }
        val encoder = Base64.getEncoder()
        if (deserializedSelectedSettlementMethod != null) {
            val selectedSettlementMethod = takenOffer.settlementMethods.firstOrNull {
                deserializedSelectedSettlementMethod.currency == it.currency &&
                        deserializedSelectedSettlementMethod.price == it.price &&
                        deserializedSelectedSettlementMethod.method == it.method
            }
            if (selectedSettlementMethod != null) {
                newSwap.makerPrivateSettlementMethodData = selectedSettlementMethod.privateData
            } else {
                Log.w(logTag, "handleNewSwap: unable to find settlement for offer ${takenOffer.id} matching " +
                        "that selected by taker: ${encoder.encodeToString(swapOnChain.settlementMethod)}")
            }
        } else {
            Log.w(logTag, "handleNewSwap: unable to deserialize selected settlement method ${encoder
                .encodeToString(swapOnChain.settlementMethod)} for ${takenOffer.id}")
        }
        // TODO: check for taker information once SettlementMethodService is implemented
        Log.i(logTag, "handleNewSwap: persistently storing ${takenOffer.id}")
        val swapForDatabase = DatabaseSwap(
            id = encoder.encodeToString(takenOffer.id.asByteArray()),
            isCreated = if (newSwap.isCreated) 1L else 0L,
            requiresFill = if (newSwap.requiresFill) 1L else 0L,
            maker = newSwap.maker,
            makerInterfaceID = encoder.encodeToString(newSwap.makerInterfaceID),
            taker = newSwap.taker,
            takerInterfaceID = encoder.encodeToString(newSwap.takerInterfaceID),
            stablecoin = newSwap.stablecoin,
            amountLowerBound = newSwap.amountLowerBound.toString(),
            amountUpperBound = newSwap.amountUpperBound.toString(),
            securityDepositAmount = newSwap.securityDepositAmount.toString(),
            takenSwapAmount = newSwap.takenSwapAmount.toString(),
            serviceFeeAmount = newSwap.serviceFeeAmount.toString(),
            serviceFeeRate = newSwap.serviceFeeRate.toString(),
            onChainDirection = newSwap.onChainDirection.toString(),
            settlementMethod = encoder.encodeToString(newSwap.onChainSettlementMethod),
            makerPrivateData = newSwap.makerPrivateSettlementMethodData,
            makerPrivateDataInitializationVector = null,
            takerPrivateData = null,
            takerPrivateDataInitializationVector = null,
            protocolVersion = newSwap.protocolVersion.toString(),
            isPaymentSent = if (newSwap.isPaymentSent) 1L else 0L,
            isPaymentReceived = if (newSwap.isPaymentReceived) 1L else 0L,
            hasBuyerClosed = if (newSwap.hasBuyerClosed) 1L else 0L,
            hasSellerClosed = if (newSwap.hasSellerClosed) 1L else 0L,
            disputeRaiser = newSwap.onChainDisputeRaiser.toString(),
            chainID = newSwap.chainID.toString(),
            state = newSwap.state.value.asString,
            role = newSwap.role.asString,
            reportPaymentSentState = newSwap.reportingPaymentSentState.value.asString,
            reportPaymentSentTransactionHash = null,
            reportPaymentSentTransactionCreationTime = null,
            reportPaymentSentTransactionCreationBlockNumber = null,
            reportPaymentReceivedState = newSwap.reportingPaymentReceivedState.value.asString,
            reportPaymentReceivedTransactionHash = null,
            reportPaymentReceivedTransactionCreationTime = null,
            reportPaymentReceivedTransactionCreationBlockNumber = null,
            closeSwapState = newSwap.closingSwapState.value.asString,
            closeSwapTransactionHash = null,
            closeSwapTransactionCreationTime = null,
            closeSwapTransactionCreationBlockNumber = null,
        )
        databaseService.storeSwap(swapForDatabase)
        // Add new Swap to swapTruthSource
        withContext(Dispatchers.Main) {
            swapTruthSource.addSwap(newSwap)
        }
        Log.i(logTag, "handleNewSwap: successfully handled ${takenOffer.id}")
    }

    /**
     * The function called by [P2PService] to notify [SwapService] of a [TakerInformationMessage].
     *
     * Once notified, this checks that there exists in [swapTruthSource] a [Swap] with the ID specified in [message]. If
     * there is, this checks that the interface ID of the public key contained in [message] is equal to the interface ID
     * of the swap taker, and that the user is the maker of the swap. If these conditions are met, this persistently
     * stores the public key in [message], securely persistently stores the taker's private settlement method data
     * contained in [message], updates the state of the swap to [SwapState.AWAITING_MAKER_INFORMATION] (both
     * persistently and in [swapTruthSource] on the main coroutine dispatcher), and creates and sends a Maker
     * Information Message. Then, if the swap is a maker-as-seller swap, this updates the state of the swap to
     * [SwapState.AWAITING_FILLING]. Otherwise, the swap is a maker-as-buyer swap, and this updates the state of the
     * swap to [SwapState.AWAITING_PAYMENT_SENT]. The state is updated both persistently and in [swapTruthSource].
     *
     * @param message The [TakerInformationMessage] to handle.
     *
     * @throws SwapServiceException If [keyManagerService] does not have the key pair with the interface ID specified in
     * [message].
     */
    override suspend fun handleTakerInformationMessage(message: TakerInformationMessage) {
        Log.i(logTag, "handleTakerInformationMessage: handling for ${message.swapID}")
        val swap = swapTruthSource.swaps[message.swapID]
        if (swap != null) {
            if (message.publicKey.interfaceId.contentEquals(swap.takerInterfaceID)) {
                /*
                We should only handle this message if we are the maker of the swap; otherwise, we are the taker and we
                would be handling our own message
                 */
                if (swap.role == SwapRole.MAKER_AND_BUYER || swap.role == SwapRole.MAKER_AND_SELLER) {
                    val encoder = Base64.getEncoder()
                    Log.i(logTag, "handleTakerInformationMessage: persistently storing public key " +
                            "${encoder.encodeToString(message.publicKey.interfaceId)} for ${message.swapID}")
                    keyManagerService.storePublicKey(pubKey = message.publicKey)
                    val swapIDB64String = encoder.encodeToString(message.swapID.asByteArray())
                    if (message.settlementMethodDetails == null) {
                        Log.w(logTag, "handleTakerInformationMessage: private data in message was null for " +
                                "${message.swapID}")
                    } else {
                        Log.i(logTag, "handleTakerInformationMessage: persistently storing private data in message " +
                                "for ${message.swapID}")
                        databaseService.updateSwapTakerPrivateSettlementMethodData(
                            swapID = swapIDB64String,
                            chainID = swap.chainID.toString(),
                            data = message.settlementMethodDetails
                        )
                        Log.i(logTag, "handleTakerInformationMessage: updating ${swap.id} with private data")
                        withContext(Dispatchers.Main) {
                            swap.takerPrivateSettlementMethodData = message.settlementMethodDetails
                        }
                    }
                    Log.i(logTag, "handleTakerInformationMessage: updating ${swap.id} to " +
                            SwapState.AWAITING_MAKER_INFORMATION.asString)
                    databaseService.updateSwapState(
                        swapID = swapIDB64String,
                        chainID = swap.chainID.toString(),
                        state = SwapState.AWAITING_MAKER_INFORMATION.asString,
                    )
                    withContext(Dispatchers.Main) {
                        swap.state.value = SwapState.AWAITING_MAKER_INFORMATION
                    }
                    val makerKeyPair = keyManagerService.getKeyPair(swap.makerInterfaceID)
                        ?: throw SwapServiceException("Could not find key pair for ${message.swapID} while handling " +
                                "Taker Information Message")
                    Log.i(logTag, "handleTakerInformationMessage: sending for ${message.swapID}")
                    if (swap.makerPrivateSettlementMethodData == null) {
                        Log.w(logTag, "handleTakerInformationMessage: maker info is null for ${swap.id}")
                    }
                    p2pService.sendMakerInformation(
                        takerPublicKey = message.publicKey,
                        makerKeyPair = makerKeyPair,
                        swapID = message.swapID,
                        settlementMethodDetails = swap.makerPrivateSettlementMethodData
                    )
                    Log.i(logTag, "handleTakerInformationMessage: sent for ${message.swapID}")
                    when (swap.direction) {
                        OfferDirection.BUY -> {
                            Log.i(logTag, "handleTakerInformationMessage: updating state of BUY swap " +
                                    "${message.swapID} to ${SwapState.AWAITING_PAYMENT_SENT.asString}")
                            databaseService.updateSwapState(
                                swapID = swapIDB64String,
                                chainID = swap.chainID.toString(),
                                state = SwapState.AWAITING_PAYMENT_SENT.asString,
                            )
                            withContext(Dispatchers.Main) {
                                swap.state.value = SwapState.AWAITING_PAYMENT_SENT
                            }
                        }
                        OfferDirection.SELL -> {
                            Log.i(logTag, "handleTakerInformationMessage: updating state of SELL swap " +
                                    "${message.swapID} to ${SwapState.AWAITING_FILLING.asString}")
                            databaseService.updateSwapState(
                                swapID = swapIDB64String,
                                chainID = swap.chainID.toString(),
                                state = SwapState.AWAITING_FILLING.asString,
                            )
                            withContext(Dispatchers.Main) {
                                swap.state.value = SwapState.AWAITING_FILLING
                            }
                        }
                    }
                    Log.i(logTag, "handleTakerInformation: detected own message for ${message.swapID}")
                }
            } else {
                Log.w(logTag, "handleTakerInformationMessage: got message for ${message.swapID} that was not " +
                        "sent by swap taker")
            }
        } else {
            Log.w(logTag, "handleTakerInformationMessage: got message for ${message.swapID} which was not found " +
                    "in swapTruthSource")
        }
    }

    /**
     * The function called by [P2PService] to notify [SwapService] of a [MakerInformationMessage].
     *
     * Once notified, this checks that there exists in [swapTruthSource] a [Swap] with the ID specified in [message]. If
     * there is, this checks that the interface ID of the message sender is equal to the interface ID of the swap maker
     * and that the interface ID of the message's intended recipient is equal to the interface ID of the swap taker. If
     * they are, this securely persistently stores the settlement method information in [message]. Then, if this swap is
     * a maker-as-buyer swap, this updates the state of the swap to [SwapState.AWAITING_PAYMENT_SENT]. Otherwise, the
     * swap is a maker-as-seller swap, and this updates the state of the swap to [SwapState.AWAITING_FILLING]. The state
     * is updated both persistently and in [swapTruthSource].
     *
     * @param message The [MakerInformationMessage] to handle.
     * @param senderInterfaceID The interface ID of the message's sender.
     * @param recipientInterfaceID The interface ID of the message's intended recipient.
     */
    override suspend fun handleMakerInformationMessage(
        message: MakerInformationMessage,
        senderInterfaceID: ByteArray,
        recipientInterfaceID: ByteArray
    ) {
        Log.i(logTag, "handleMakerInformationMessage: handling for ${message.swapID}")
        val swap = swapTruthSource.swaps[message.swapID]
        if (swap != null) {
            /*
            We should only handle this message if we are the taker of the swap; otherwise, we are the maker and we would
            be handling our own message
             */
            if (swap.role == SwapRole.TAKER_AND_BUYER || swap.role == SwapRole.TAKER_AND_SELLER) {
                if (!senderInterfaceID.contentEquals(swap.makerInterfaceID)) {
                    Log.w(logTag, "handleMakerInformationMessage: got message for ${message.swapID} that was not " +
                            "sent by swap maker")
                    return
                }
                val encoder = Base64.getEncoder()
                if (!recipientInterfaceID.contentEquals(swap.takerInterfaceID)) {
                    Log.w(logTag, "handleMakerInformationMessage: got message for ${message.swapID} with recipient " +
                            "interface ID ${encoder.encodeToString(recipientInterfaceID)} that doesn't match taker " +
                            "interface ID ${encoder.encodeToString(swap.takerInterfaceID)}")
                    return
                }
                val swapIDB64String = encoder.encodeToString(message.swapID.asByteArray())
                if (message.settlementMethodDetails == null) {
                    Log.w(logTag, "handleMakerInformationMessage: private data in message was null for " +
                            "${message.swapID}")
                } else {
                    Log.i(logTag, "handleMakerInformationMessage: persistently storing private data in message " +
                            "for ${message.swapID}")
                    databaseService.updateSwapMakerPrivateSettlementMethodData(
                        swapID = swapIDB64String,
                        chainID = swap.chainID.toString(),
                        data = message.settlementMethodDetails,
                    )
                    Log.i(logTag, "handleMakerInformationMessage: updating ${swap.id} with private data")
                    withContext(Dispatchers.Main) {
                        swap.makerPrivateSettlementMethodData = message.settlementMethodDetails
                    }
                }
                when (swap.direction) {
                    OfferDirection.BUY -> {
                        Log.i(logTag, "handleMakerInformationMessage: updating state of BUY swap ${message.swapID} " +
                                "to ${SwapState.AWAITING_PAYMENT_SENT.asString}")
                        databaseService.updateSwapState(
                            swapID = swapIDB64String,
                            chainID = swap.chainID.toString(),
                            state = SwapState.AWAITING_PAYMENT_SENT.asString,
                        )
                        withContext(Dispatchers.Main) {
                            swap.state.value = SwapState.AWAITING_PAYMENT_SENT
                        }
                    }
                    OfferDirection.SELL -> {
                        Log.i(logTag, "handleMakerInformationMessage: updating state of SELL swap ${message.swapID} " +
                                "to ${SwapState.AWAITING_FILLING.asString}")
                        databaseService.updateSwapState(
                            swapID = swapIDB64String,
                            chainID = swap.chainID.toString(),
                            state = SwapState.AWAITING_FILLING.asString,
                        )
                        withContext(Dispatchers.Main) {
                            swap.state.value = SwapState.AWAITING_FILLING
                        }
                    }
                }
            } else {
                Log.i(logTag, "handleMakerInformationMessage: detected own message for ${message.swapID}")
            }
        } else {
            Log.w(logTag, "handleMakerInformationMessage: got message for ${message.swapID} which was not found " +
                    "in swapTruthSource")
        }
    }

    /**
     * The function called by [BlockchainService] to notify [SwapService] of a [SwapFilledEvent].
     *
     * Once notified, [SwapService] checks in [swapTruthSource] for a [Swap] with the ID specified in [event]. If it
     * finds such a swap, it ensures that the chain ID of the swap and the chain ID of [event] match. Then, if the role
     * of the swap is [SwapRole.MAKER_AND_BUYER] or [SwapRole.TAKER_AND_SELLER], it logs a warning, since
     * [SwapFilledEvent]s should not be emitted for such swaps. Otherwise, the role is [SwapRole.MAKER_AND_SELLER] or
     * [SwapRole.TAKER_AND_BUYER], and this persistently sets the state of the swap to [SwapState.AWAITING_PAYMENT_SENT]
     * and requiresFill to `false`, and then does the same to the [Swap] object on the main coroutine dispatcher.
     *
     * @param event The [SwapFilledEvent] of which [SwapService] is being notified.
     *
     * @throws SwapServiceException if the chain ID of [event] and the chain ID of the [Swap] with the ID specified in
     * [event] do not match.
     */
    override suspend fun handleSwapFilledEvent(event: SwapFilledEvent) {
        Log.i(logTag, "handleSwapFilledEvent: handing for ${event.swapID}")
        swapTruthSource.swaps[event.swapID]?.let { swap ->
            // Executed if we have a Swap with the ID specified in event
            if (swap.chainID != event.chainID) {
                throw SwapServiceException("Chain ID of SwapFilledEvent did not match chain ID of Swap in " +
                        "handleSwapFilledEvent call. SwapFilledEvent.chainID: ${event.chainID}, Swap.chainID: " +
                        "${swap.chainID}, SwapFilledEvent.id: ${event.swapID}")
            }
            /*
            At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
             */
            when (swap.role) {
                SwapRole.MAKER_AND_BUYER, SwapRole.TAKER_AND_SELLER -> {
                    /*
                    If we are the maker of and buyer in or taker of and seller in the swap, no SwapFilled event should
                    be emitted for that swap
                     */
                    Log.w(logTag, "handleSwapFilledEvent: unexpectedly got event for ${event.swapID} with role " +
                            swap.role.asString)
                }
                SwapRole.MAKER_AND_SELLER, SwapRole.TAKER_AND_BUYER -> {
                    Log.i(logTag, "handleSwapFilledEvent: handing for ${event.swapID} as ${swap.role.asString}")
                    /*
                    We have gotten confirmation that the fillSwap transaction has been confirmed, so we update the state
                    of the swap to indicate that we are waiting for the buyer to send traditional currency payment
                     */
                    val swapIDB64String = Base64.getEncoder().encodeToString(event.swapID.asByteArray())
                    databaseService.updateSwapRequiresFill(
                        swapID = swapIDB64String,
                        chainID = event.chainID.toString(),
                        requiresFill = false
                    )
                    databaseService.updateSwapState(
                        swapID = swapIDB64String,
                        chainID = event.chainID.toString(),
                        state = SwapState.AWAITING_PAYMENT_SENT.asString
                    )
                    swap.requiresFill = false
                    withContext(Dispatchers.Main) {
                        swap.state.value =  SwapState.AWAITING_PAYMENT_SENT
                    }
                }
            }
        } ?: run {
            // Executed if we do not have a Swap with the ID specified in event
            Log.i(logTag, "handleSwapFilledEvent: ${event.swapID} not made or taken by user")
            return
        }
    }

    /**
     * The function called by [BlockchainService] to notify [SwapService] of a [PaymentSentEvent].
     *
     * Once notified, [SwapService] checks in [swapTruthSource] for a [Swap] with the ID specified in [event]. If it
     * finds such a swap, it ensures that the chain ID of the swap and the chain ID of [event] match. Then it
     * persistently sets the swap's [Swap.isPaymentSent] field to `true` and the state of the swap to
     * [SwapState.AWAITING_PAYMENT_RECEIVED], and then does the same to the [Swap] object on the main coroutine
     * dispatcher.
     *
     * @param event The [PaymentSentEvent] of which [SwapService] is being notified.
     *
     * @throws SwapServiceException if the chain ID of [event] and the chain ID of the [Swap] with the ID specified
     * in [event] do not match.
     */
    override suspend fun handlePaymentSentEvent(event: PaymentSentEvent) {
        Log.i(logTag, "handlePaymentSentEvent: handing for ${event.swapID}")
        swapTruthSource.swaps[event.swapID]?.let { swap ->
            // Executed if we have a Swap with the ID specified in event
            if (swap.chainID != event.chainID) {
                throw SwapServiceException("Chain ID of PaymentSentEvent did not match chain ID of Swap in " +
                        "handlePaymentSentEvent call. PaymentSentEvent.chainID: ${event.chainID}, Swap.chainID: " +
                        "${swap.chainID}, PaymentSentEvent.id: ${event.swapID}")
            }
            /*
            At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
             */
            var mustUpdateReportPaymentSentTransaction = false
            if (swap.role == SwapRole.MAKER_AND_BUYER || swap.role == SwapRole.TAKER_AND_BUYER) {
                Log.i(logTag, "handlePaymentSentEvent: user is buyer for ${event.swapID}")
                swap.reportPaymentSentTransaction?.let { reportPaymentSentTransaction ->
                    if (reportPaymentSentTransaction.transactionHash == event.transactionHash) {
                        Log.i(logTag, "handlePaymentSentEvent: tx hash ${event.transactionHash} of event " +
                                "matches that for swap ${swap.id}: ${reportPaymentSentTransaction.transactionHash}")
                    } else {
                        Log.w(logTag, "handlePaymentSentEvent: tx hash ${event.transactionHash} of event does " +
                                "not match that for swap ${event.swapID}: ${reportPaymentSentTransaction
                                    .transactionHash}, updating with new transaction hash")
                        mustUpdateReportPaymentSentTransaction = true
                    }
                } ?: run {
                    Log.w(logTag, "handlePaymentSentEvent: swap ${event.swapID} for which user is buyer has no " +
                            "reporting payment sent transaction, updating with transaction hash ${event
                                .transactionHash}")
                    mustUpdateReportPaymentSentTransaction = true
                }
            } else {
                Log.i(logTag, "handlePaymentSentEvent: user is seller for ${event.swapID}, updating with " +
                        "transaction hash ${event.transactionHash}")
                mustUpdateReportPaymentSentTransaction = true
            }
            val encoder = Base64.getEncoder()
            if (mustUpdateReportPaymentSentTransaction) {
                val reportPaymentSentTransaction = BlockchainTransaction(
                    transactionHash = event.transactionHash,
                    timeOfCreation = Date(),
                    latestBlockNumberAtCreation = BigInteger.ZERO,
                    type = BlockchainTransactionType.REPORT_PAYMENT_SENT
                )
                withContext(Dispatchers.Main) {
                    swap.reportPaymentSentTransaction = reportPaymentSentTransaction
                }
                Log.i(logTag, "handlePaymentSentEvent: persistently storing tx data, including hash ${event
                    .transactionHash} for ${event.swapID}")
                val dateString = DateFormatter.createDateString(reportPaymentSentTransaction.timeOfCreation)
                databaseService.updateReportPaymentSentData(
                    swapID = encoder.encodeToString(event.swapID.asByteArray()),
                    chainID = event.chainID.toString(),
                    transactionHash = reportPaymentSentTransaction.transactionHash,
                    creationTime = dateString,
                    blockNumber = reportPaymentSentTransaction.latestBlockNumberAtCreation.toLong()
                )
            }
            Log.i(logTag, "handlePaymentSentEvent: persistently setting isPaymentSent property of ${event
                .swapID} to true")
            databaseService.updateSwapIsPaymentSent(
                swapID = encoder.encodeToString(event.swapID.asByteArray()),
                chainID = event.chainID.toString(),
                isPaymentSent = true
            )
            Log.i(logTag, "handlePaymentSentEvent: persistently updating state of ${event.swapID} to " +
                    SwapState.AWAITING_PAYMENT_RECEIVED.asString)
            databaseService.updateSwapState(
                swapID = encoder.encodeToString(event.swapID.asByteArray()),
                chainID = event.chainID.toString(),
                state = SwapState.AWAITING_PAYMENT_RECEIVED.asString
            )
            Log.i(logTag, "handlePaymentSentEvent: setting isPaymentSent property of ${event.swapID} to true " +
                    "and setting state to ${SwapState.AWAITING_PAYMENT_RECEIVED.asString}")
            withContext(Dispatchers.Main) {
                swap.isPaymentSent = true
                swap.state.value = SwapState.AWAITING_PAYMENT_RECEIVED
            }
            if (swap.role == SwapRole.MAKER_AND_BUYER || swap.role == SwapRole.TAKER_AND_BUYER) {
                Log.i(logTag, "handlePaymentSentEvent: user is buyer for ${event.swapID} so persistently " +
                        "updating reportingPaymentSentState to ${ReportingPaymentSentState.COMPLETED.asString}")
                databaseService.updateReportPaymentSentState(
                    swapID = encoder.encodeToString(event.swapID.asByteArray()),
                    chainID = event.chainID.toString(),
                    state = ReportingPaymentSentState.COMPLETED.asString
                )
                Log.i(logTag, "handlePaymentSentEvent: updating reportingPaymentSentState to " +
                        ReportingPaymentSentState.COMPLETED.asString
                )
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentSentState.value = ReportingPaymentSentState.COMPLETED
                }
            }
        } ?: run {
            // Executed if we do not have a Swap with the ID specified in event
            Log.i(logTag, "handlePaymentSentEvent: got event for ${event.swapID} which was not found in " +
                    "swapTruthSource")
        }
    }

    /**
     * The function called by [BlockchainService] to notify [SwapService] of a [PaymentReceivedEvent].
     *
     * Once notified, [SwapService] checks in [swapTruthSource] for a [Swap] with the ID specified in [event]. If it
     * finds such a swap, it ensures that the chain ID of the swap and the chain ID of [event] match. Then it
     * persistently sets the swap's [Swap.isPaymentReceived] field to `true` and the state of the swap to
     * [SwapState.AWAITING_CLOSING], and then does the same to the [Swap] object on the main coroutine dispatcher.
     *
     * @param event The [PaymentReceivedEvent] of which [SwapService] is being notified.
     *
     * @throws SwapServiceException if the chain ID of [event] and the chain ID of the [Swap] with the ID specified
     * in [event] do not match.
     */
    override suspend fun handlePaymentReceivedEvent(event: PaymentReceivedEvent) {
        Log.i(logTag, "handlePaymentReceivedEvent: handing for ${event.swapID}")
        swapTruthSource.swaps[event.swapID]?.let { swap ->
            // Executed if we have a Swap with the ID specified in event
            if (swap.chainID != event.chainID) {
                throw SwapServiceException("Chain ID of PaymentReceivedEvent did not match chain ID of Swap in " +
                        "handlePaymentReceivedEvent call. PaymentReceivedEvent.chainID: ${event.chainID}, " +
                        "Swap.chainID: ${swap.chainID}, PaymentReceivedEvent.id: ${event.swapID}")
            }
            /*
            At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
             */
            var mustUpdateReportPaymentReceivedTransaction = false
            if (swap.role == SwapRole.MAKER_AND_SELLER || swap.role == SwapRole.TAKER_AND_SELLER) {
                Log.i(logTag, "handlePaymentReceivedEvent: user is buyer for ${event.swapID}")
                swap.reportPaymentReceivedTransaction?.let { reportPaymentReceivedTransaction ->
                    if (reportPaymentReceivedTransaction.transactionHash == event.transactionHash) {
                        Log.i(logTag, "handlePaymentReceivedEvent: tx hash ${event.transactionHash} of event " +
                                "matches that for swap ${swap.id}: ${reportPaymentReceivedTransaction.transactionHash}")
                    } else {
                        Log.w(logTag, "handlePaymentReceivedEvent: tx hash ${event.transactionHash} of event " +
                                "does not match that for swap ${event.swapID}: ${reportPaymentReceivedTransaction
                                    .transactionHash}, updating with new transaction hash")
                        mustUpdateReportPaymentReceivedTransaction = true
                    }
                } ?: run {
                    Log.w(logTag, "handlePaymentReceivedEvent: swap ${event.swapID} for which user is buyer has " +
                            "no reporting payment sent transaction, updating with transaction hash ${event
                                .transactionHash}")
                    mustUpdateReportPaymentReceivedTransaction = true
                }
            } else {
                Log.i(logTag, "handlePaymentReceivedEvent: user is seller for ${event.swapID}, updating with " +
                        "transaction hash ${event.transactionHash}")
                mustUpdateReportPaymentReceivedTransaction = true
            }
            val encoder = Base64.getEncoder()
            if (mustUpdateReportPaymentReceivedTransaction) {
                val reportPaymentReceivedTransaction = BlockchainTransaction(
                    transactionHash = event.transactionHash,
                    timeOfCreation = Date(),
                    latestBlockNumberAtCreation = BigInteger.ZERO,
                    type = BlockchainTransactionType.REPORT_PAYMENT_SENT
                )
                withContext(Dispatchers.Main) {
                    swap.reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
                }
                Log.i(logTag, "handlePaymentReceivedEvent: persistently storing tx data, including hash ${event
                    .transactionHash} for ${event.swapID}")
                val dateString = DateFormatter.createDateString(reportPaymentReceivedTransaction.timeOfCreation)
                databaseService.updateReportPaymentReceivedData(
                    swapID = encoder.encodeToString(event.swapID.asByteArray()),
                    chainID = event.chainID.toString(),
                    transactionHash = reportPaymentReceivedTransaction.transactionHash,
                    creationTime = dateString,
                    blockNumber = reportPaymentReceivedTransaction.latestBlockNumberAtCreation.toLong()
                )
            }
            Log.i(logTag, "handlePaymentReceivedEvent: persistently setting isPaymentReceived property of ${event
                .swapID} to true")
            databaseService.updateSwapIsPaymentReceived(
                swapID = encoder.encodeToString(event.swapID.asByteArray()),
                chainID = event.chainID.toString(),
                isPaymentReceived = true
            )
            Log.i(logTag, "handlePaymentReceivedEvent: persistently updating state of ${event.swapID} to " +
                    SwapState.AWAITING_CLOSING.asString)
            databaseService.updateSwapState(
                swapID = encoder.encodeToString(event.swapID.asByteArray()),
                chainID = event.chainID.toString(),
                state = SwapState.AWAITING_CLOSING.asString
            )
            Log.i(logTag, "handlePaymentReceivedEvent: setting isPaymentReceived property of ${event.swapID} to " +
                    "true and setting state to ${SwapState.AWAITING_CLOSING.asString}")
            withContext(Dispatchers.Main) {
                swap.isPaymentReceived = true
                swap.state.value = SwapState.AWAITING_CLOSING
            }
            if (swap.role == SwapRole.MAKER_AND_SELLER || swap.role == SwapRole.TAKER_AND_SELLER) {
                Log.i(logTag, "handlePaymentReceivedEvent: user is seller for ${event.swapID} so persistently " +
                        "updating reportingPaymentReceivedState to ${ReportingPaymentReceivedState.COMPLETED.asString}")
                databaseService.updateReportPaymentReceivedState(
                    swapID = encoder.encodeToString(event.swapID.asByteArray()),
                    chainID = event.chainID.toString(),
                    state = ReportingPaymentReceivedState.COMPLETED.asString
                )
                Log.i(logTag, "handlePaymentReceivedEvent: updating reportingPaymentReceivedState to " +
                        ReportingPaymentReceivedState.COMPLETED.asString
                )
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.COMPLETED
                }
            }
        } ?: run {
            // Executed if we do not have a Swap with the ID specified in event
            Log.i(logTag, "handlePaymentReceivedEvent: got event for ${event.swapID} which was not found in " +
                    "swapTruthSource")
        }
    }

    /**
     * The function called by [BlockchainService] to notify [SwapService] of a [BuyerClosedEvent].
     *
     * Once notified, [SwapService] checks in [swapTruthSource] for a [Swap] with the ID specified in [event]. If it
     * finds such a [Swap], it ensures that the chain ID of the [Swap] and the chain ID of [event] match. Then it checks
     * whether the user is the buyer in the [Swap]. If the user is, then this checks if the swap has a non-`null`
     * transaction for calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap). If
     * it does, then this compares the hash of that transaction and the transaction hash contained in [event] If the two
     * do not match, this sets a flag indicating that the swap closing transaction must be updated. If the swap does not
     * have such a transaction, this flag is also set. If this flag is set, then this updates the [Swap], both in
     * [swapTruthSource] and in persistent storage, with a new [BlockchainTransaction] containing the hash specified in
     * [event]. Then, regardless of whether this flag is set, this persistently updates the [Swap.state] property of the
     * [Swap] to [SwapState.CLOSED], on the main coroutine dispatcher sets the [Swap.state] property of the [Swap] to
     * [SwapState.CLOSED], persistently updates the [Swap.closingSwapState] of the [Swap] to
     * [ClosingSwapState.COMPLETED], and on the main coroutine dispatcher sets the [Swap.closingSwapState] property of
     * the [Swap] to [ClosingSwapState.COMPLETED]. Then, regardless of whether the user of this interface is the buyer
     * or seller, this persistently updates the [Swap.hasBuyerClosed] property of the [Swap] to `true`, and then on the
     * main coroutine dispatcher sets the [Swap.hasBuyerClosed] property to `true`.
     *
     * @param event The [BuyerClosedEvent] of which [SwapService] is being notified.
     *
     * @throws [SwapServiceException] if the chain ID of [event] and the chain ID of the [Swap] with the ID specified in
     * [event] do not match.
     */
    override suspend fun handleBuyerClosedEvent(event: BuyerClosedEvent) {
        Log.i(logTag, "handleBuyerClosedEvent: handling for ${event.swapID}")
        swapTruthSource.swaps[event.swapID]?.let { swap ->
            if (swap.chainID != event.chainID) {
                throw SwapServiceException("Chain ID of BuyerClosedEvent did not match chain ID of Swap in " +
                        "handleBuyerClosedEvent call. BuyerClosedEvent.chainID: ${event.chainID}, Swap.chainID: " +
                        "${swap.chainID}, BuyerClosedEvent.id: ${event.swapID}")
            }
            val encoder = Base64.getEncoder()
            if (swap.role == SwapRole.MAKER_AND_BUYER || swap.role == SwapRole.TAKER_AND_BUYER) {
                Log.i(logTag, "handleBuyerClosedEvent: user is buyer for ${event.swapID}")
                var mustUpdateCloseSwapTransaction = false
                swap.closeSwapTransaction?.let { closeSwapTransaction ->
                    if (closeSwapTransaction.transactionHash == event.transactionHash) {
                        Log.i(logTag, "handleBuyerClosedEvent: tx hash ${event.transactionHash} of event matches " +
                                "that for swap ${swap.id}: ${closeSwapTransaction.transactionHash}")
                    } else {
                        Log.w(logTag, "handleBuyerClosedEvent: tx hash ${event.transactionHash} of event does not " +
                                "match that for swap ${event.swapID}: ${closeSwapTransaction.transactionHash}")
                        mustUpdateCloseSwapTransaction = true
                    }
                } ?: run {
                    Log.w(logTag, "handleBuyerClosedEvent: swap ${event.swapID} for which user is buyer has no " +
                            "closing swap transaction, updating with transaction hash ${event.transactionHash}")
                    mustUpdateCloseSwapTransaction = true
                }
                if (mustUpdateCloseSwapTransaction) {
                    val closeSwapTransaction = BlockchainTransaction(
                        transactionHash = event.transactionHash,
                        timeOfCreation = Date(),
                        latestBlockNumberAtCreation = BigInteger.ZERO,
                        type = BlockchainTransactionType.CLOSE_SWAP
                    )
                    withContext(Dispatchers.Main) {
                        swap.closeSwapTransaction = closeSwapTransaction
                    }
                    Log.i(logTag, "handleBuyerClosedEvent: persistently storing tx data, including hash ${event
                        .transactionHash} for ${event.swapID}")
                    val dateString = DateFormatter.createDateString(closeSwapTransaction.timeOfCreation)
                    databaseService.updateCloseSwapData(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        transactionHash = closeSwapTransaction.transactionHash,
                        creationTime = dateString,
                        blockNumber = closeSwapTransaction.latestBlockNumberAtCreation.toLong()
                    )
                }
                Log.i(logTag, "handleBuyerClosedEvent: persistently updating state of ${event.swapID} to ${SwapState
                    .CLOSED.asString}")
                databaseService.updateSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.CLOSED.asString
                )
                Log.i(logTag, "handleBuyerClosedEvent: setting state of ${event.swapID} to ${SwapState.CLOSED
                    .asString}")
                withContext(Dispatchers.Main) {
                    swap.state.value = SwapState.CLOSED
                }
                Log.i(logTag, "handleBuyerClosedEvent: user is buyer for ${event.swapID} so persistently " +
                        "updating closingSwapState to ${ClosingSwapState.COMPLETED.asString}")
                databaseService.updateCloseSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ClosingSwapState.COMPLETED.asString
                )
                withContext(Dispatchers.Main) {
                    swap.closingSwapState.value = ClosingSwapState.COMPLETED
                }
            } else {
                Log.i(logTag, "handleBuyerClosedEvent: user is seller for ${event.swapID}")
            }
            Log.i(logTag, "handleBuyerClosedEvent: persistently setting hasBuyerClosed property of ${event.swapID} to " +
                    "true")
            databaseService.updateSwapHasBuyerClosed(
                swapID = encoder.encodeToString(swap.id.asByteArray()),
                chainID = event.chainID.toString(),
                hasBuyerClosed = true
            )
            Log.i(logTag, "handleBuyerClosedEvent: setting hasBuyerClosed property of ${event.swapID} to true")
            withContext(Dispatchers.Main) {
                swap.hasBuyerClosed = true
            }
        } ?: run {
            // Executed if we do not have a Swap with the ID specified in event
            Log.i(logTag, "handleBuyerClosedEvent: got event for ${event.swapID} which was not found in " +
                    "swapTruthSource")
        }
    }

    /**
     * The function called by [BlockchainService] to notify [SwapService] of a [SellerClosedEvent].
     *
     * Once notified, [SwapService] checks in [swapTruthSource] for a [Swap] with the ID specified in [event]. If it
     * finds such a [Swap], it ensures that the chain ID of the [Swap] and the chain ID of [event] match. Then it checks
     * whether the user is the seller in the [Swap]. If the user is, then this checks if the swap has a non-`null`
     * transaction for calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap). If
     * it does, then this compares the hash of that transaction and the transaction hash contained in [event] If the two
     * do not match, this sets a flag indicating that the swap closing transaction must be updated. If the swap does not
     * have such a transaction, this flag is also set. If this flag is set, then this updates the [Swap], both in
     * [swapTruthSource] and in persistent storage, with a new [BlockchainTransaction] containing the hash specified in
     * [event]. Then, regardless of whether this flag is set, this persistently updates the [Swap.state] property of the
     * [Swap] to [SwapState.CLOSED], on the main coroutine dispatcher sets the [Swap.state] property of the [Swap] to
     * [SwapState.CLOSED], persistently updates the [Swap.closingSwapState] of the [Swap] to
     * [ClosingSwapState.COMPLETED], and on the main coroutine dispatcher sets the [Swap.closingSwapState] property of
     * the [Swap] to [ClosingSwapState.COMPLETED]. Then, regardless of whether the user of this interface is the buyer
     * or seller, this persistently updates the [Swap.hasSellerClosed] property of the [Swap] to `true`, and then on the
     * main coroutine dispatcher sets the [Swap.hasSellerClosed] property to `true`.
     *
     * @param event The [SellerClosedEvent] of which [SwapService] is being notified.
     *
     * @throws [SwapServiceException] if the chain ID of [event] and the chain ID of the [Swap] with the ID specified in
     * [event] do not match.
     */
    override suspend fun handleSellerClosedEvent(event: SellerClosedEvent) {
        Log.i(logTag, "handleSellerClosedEvent: handling for ${event.swapID}")
        swapTruthSource.swaps[event.swapID]?.let { swap ->
            if (swap.chainID != event.chainID) {
                throw SwapServiceException("Chain ID of SellerClosedEvent did not match chain ID of Swap in " +
                        "handleSellerClosedEvent call. SellerClosedEvent.chainID: ${event.chainID}, Swap.chainID: " +
                        "${swap.chainID}, SellerClosedEvent.id: ${event.swapID}")
            }
            val encoder = Base64.getEncoder()
            if (swap.role == SwapRole.MAKER_AND_SELLER || swap.role == SwapRole.TAKER_AND_SELLER) {
                Log.i(logTag, "handleSellerClosedEvent: user is seller for ${event.swapID}")
                var mustUpdateCloseSwapTransaction = false
                swap.closeSwapTransaction?.let { closeSwapTransaction ->
                    if (closeSwapTransaction.transactionHash == event.transactionHash) {
                        Log.i(logTag, "handleSellerClosedEvent: tx hash ${event.transactionHash} of event " +
                                "matches that for swap ${swap.id}: ${closeSwapTransaction.transactionHash}")
                    } else {
                        Log.w(logTag, "handleSellerClosedEvent: tx hash ${event.transactionHash} of event does " +
                                "not match that for swap ${event.swapID}: ${closeSwapTransaction.transactionHash}")
                        mustUpdateCloseSwapTransaction = true
                    }
                } ?: run {
                    Log.w(logTag, "handleSellerClosedEvent: swap ${event.swapID} for which user is seller has " +
                            "no closing swap transaction, updating with transaction hash ${event.transactionHash}")
                    mustUpdateCloseSwapTransaction = true
                }
                if (mustUpdateCloseSwapTransaction) {
                    val closeSwapTransaction = BlockchainTransaction(
                        transactionHash = event.transactionHash,
                        timeOfCreation = Date(),
                        latestBlockNumberAtCreation = BigInteger.ZERO,
                        type = BlockchainTransactionType.CLOSE_SWAP
                    )
                    withContext(Dispatchers.Main) {
                        swap.closeSwapTransaction = closeSwapTransaction
                    }
                    Log.i(logTag, "handleSellerClosedEvent: persistently storing tx data, including hash ${event
                        .transactionHash} for ${event.swapID}")
                    val dateString = DateFormatter.createDateString(closeSwapTransaction.timeOfCreation)
                    databaseService.updateCloseSwapData(
                        swapID = encoder.encodeToString(swap.id.asByteArray()),
                        chainID = swap.chainID.toString(),
                        transactionHash = closeSwapTransaction.transactionHash,
                        creationTime = dateString,
                        blockNumber = closeSwapTransaction.latestBlockNumberAtCreation.toLong()
                    )
                }
                Log.i(logTag, "handleSellerClosedEvent: persistently updating state of ${event.swapID} to " +
                        SwapState.CLOSED.asString
                )
                databaseService.updateSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = SwapState.CLOSED.asString
                )
                Log.i(logTag, "handleSellerClosedEvent: setting state of ${event.swapID} to ${SwapState.CLOSED
                    .asString}")
                withContext(Dispatchers.Main) {
                    swap.state.value = SwapState.CLOSED
                }
                Log.i(logTag, "handleSellerClosedEvent: user is seller for ${event.swapID} so persistently " +
                        "updating closingSwapState to ${ClosingSwapState.COMPLETED.asString}")
                databaseService.updateCloseSwapState(
                    swapID = encoder.encodeToString(swap.id.asByteArray()),
                    chainID = swap.chainID.toString(),
                    state = ClosingSwapState.COMPLETED.asString
                )
                withContext(Dispatchers.Main) {
                    swap.closingSwapState.value = ClosingSwapState.COMPLETED
                }
            } else {
                Log.i(logTag, "handleSellerClosedEvent: user is buyer for ${event.swapID}")
            }
            Log.i(logTag, "handleSellerClosedEvent: persistently setting hasSellerClosed property of ${event
                .swapID} to true")
            databaseService.updateSwapHasSellerClosed(
                swapID = encoder.encodeToString(swap.id.asByteArray()),
                chainID = event.chainID.toString(),
                hasSellerClosed = true
            )
            Log.i(logTag, "handleSellerClosedEvent: setting hasSellerClosed property of ${event.swapID} to true")
            withContext(Dispatchers.Main) {
                swap.hasSellerClosed = true
            }
        } ?: run {
            // Executed if we do not have a Swap with the ID specified in event
            Log.i(logTag, "handleSellerClosedEvent: got event for ${event.swapID} which was not found in " +
                    "swapTruthSource")
        }
    }

}
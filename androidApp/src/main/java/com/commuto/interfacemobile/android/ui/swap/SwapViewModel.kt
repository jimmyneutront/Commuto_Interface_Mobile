package com.commuto.interfacemobile.android.ui.swap

import androidx.compose.runtime.mutableStateMapOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.commuto.interfacemobile.android.offer.TokenTransferApprovalState
import com.commuto.interfacemobile.android.swap.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory
import org.web3j.crypto.RawTransaction
import java.util.*
import javax.inject.Inject

/**
 * The Swap View Model, the single source of truth for all swap-related data. It is observed by swap-related
 * [androidx.compose.runtime.Composable]s.
 *
 * @param swapService The [SwapService] used for completing the swap process for [Swap]s in [swaps].
 * @property logger The [org.slf4j.Logger] that this class uses for logging.
 * @property swaps A mutable state map of [UUID]s to [Swap]s that acts as a single source of truth for all
 * offer-related data.
 */
class SwapViewModel @Inject constructor(private val swapService: SwapService): ViewModel(), UISwapTruthSource {

    private val logger = LoggerFactory.getLogger(javaClass)

    override var swaps = mutableStateMapOf<UUID, Swap>().also { map ->
        Swap.sampleSwaps.map {
            map[it.id] = it
        }
    }

    /**
     * Adds a new [Swap] to [swaps].
     *
     * @param swap The new [Swap] to be added to [swaps].
     */
    override fun addSwap(swap: Swap) {
        swaps[swap.id] = swap
    }

    /**
     * Sets the value of [Swap.fillingSwapState] of [swap] to [state] on the main coroutine dispatcher.
     *
     * @param swap The [Swap] of which to set the [Swap.fillingSwapState] value.
     * @param state The value to which [swap]'s [Swap.fillingSwapState] value will be set.
     */
    private suspend fun setFillingSwapState(swap: Swap, state: FillingSwapState) {
        withContext(Dispatchers.Main) {
            swap.fillingSwapState.value = state
        }
    }

    /**
     * Sets the value of [Swap.reportingPaymentSentState] of [swap] to [state] on the main coroutine dispatcher.
     *
     * @param swap The [Swap] of which to set the [Swap.reportingPaymentSentState] value.
     * @param state The value to which [swap]'s [Swap.reportingPaymentSentState] value will be set.
     */
    private suspend fun setReportingPaymentSentState(swap: Swap, state: ReportingPaymentSentState) {
        withContext(Dispatchers.Main) {
            swap.reportingPaymentSentState.value = state
        }
    }

    /**
     * Sets the value of [Swap.reportingPaymentReceivedState] of [swap] to [state] on the main coroutine dispatcher.
     *
     * @param swap The [Swap] of which to set the [Swap.reportingPaymentReceivedState] value.
     * @param state The value to which [swap]'s [Swap.reportingPaymentReceivedState] value will be set.
     */
    private suspend fun setReportingPaymentReceivedState(swap: Swap, state: ReportingPaymentReceivedState) {
        withContext(Dispatchers.Main) {
            swap.reportingPaymentReceivedState.value = state
        }
    }

    /**
     * Sets the value of [Swap.closingSwapState] of [swap] to [state] on the main coroutine dispatcher.
     *
     * @param swap The [Swap] of which to set the [Swap.closingSwapState] value.
     * @param state The value to which [swap]'s [Swap.closingSwapState] value will be set.
     */
    private suspend fun setClosingSwapState(swap: Swap, state: ClosingSwapState) {
        withContext(Dispatchers.Main) {
            swap.closingSwapState.value = state
        }
    }

    /**
     * Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     *
     * @param swap The [Swap] to fill.
     */
    @Deprecated("Use the new transaction pipeline with improved transaction state management")
    override fun fillSwap(swap: Swap) {
        viewModelScope.launch {
            try {
                /*
                setFillingSwapState(
                    swap = swap,
                    state = FillingSwapState.CHECKING
                )*/
                logger.info("fillSwap: filling ${swap.id}")
                swapService.fillSwap(
                    swapToFill = swap,
                    afterPossibilityCheck = {
                        /*
                        setFillingSwapState(
                            swap = swap,
                            state = FillingSwapState.APPROVING
                        )*/
                    },
                    afterTransferApproval = {
                        /*
                        setFillingSwapState(
                            swap = swap,
                            state = FillingSwapState.FILLING
                        )*/
                    }
                )
                logger.info("fillSwap: successfully filled ${swap.id}")
                setFillingSwapState(
                    swap = swap,
                    state = FillingSwapState.COMPLETED
                )
            } catch (exception: Exception) {
                logger.error("fillSwap: got exception during fillSwap call for ${swap.id}", exception)
                swap.fillingSwapException = exception
                setFillingSwapState(
                    swap = swap,
                    state = FillingSwapState.EXCEPTION
                )
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] to approve a token transfer in order to fill a swap.
     *
     * This passes [swap] to [SwapService.createFillSwapTransaction] and then passes the resulting transaction to
     * [createdTransactionHandler] or exception to [exceptionHandler].
     *
     * @param swap The [Swap] to be filled.
     * @param createdTransactionHandler A lambda that will accept and handle the created [RawTransaction].
     * @param exceptionHandler A lambda that will accept and handle any exception that occurs during the transaction
     * creation process.
     */
    override fun createApproveTokenTransferToFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {
        viewModelScope.launch {
            logger.info("createApproveTokenTransferToTakeOfferTransaction: creating for ${swap.id}")
            try {
                val createdTransaction = swapService.createApproveTokenTransferToFillSwapTransaction(
                    swapToFill = swap
                )
                withContext(Dispatchers.Main) {
                    createdTransactionHandler(createdTransaction)
                }
            } catch (exception: Exception) {
                withContext(Dispatchers.Main) {
                    exceptionHandler(exception)
                }
            }
        }
    }

    /**
     * Attempts to approve a token transfer in order to fill a swap.
     *
     * This clears [swap]'s [Swap.approvingToFillException] property and sets its [Swap.approvingToFillState] to
     * [TokenTransferApprovalState.VALIDATING], and then passes all data to [swapService]'s
     * [SwapService.approveTokenTransferToFillSwap] function. When this function returns, this sets [swap]'s
     * [Swap.approvingToFillState] to [TokenTransferApprovalState.AWAITING_TRANSACTION_CONFIRMATION].
     *
     * @param swap The [Swap] to be filled.
     * @param approveTokenTransferToFillSwapTransaction An optional [RawTransaction] that can create a token transfer
     * allowance of the taken swap amount of the token specified by [swap].
     */
    override fun approveTokenTransferToFillSwap(
        swap: Swap,
        approveTokenTransferToFillSwapTransaction: RawTransaction?
    ) {
        swap.approvingToFillException = null
        swap.approvingToFillState.value = TokenTransferApprovalState.VALIDATING
        viewModelScope.launch {
            logger.info("approveTokenTransferToFillSwap: approving for ${swap.id}")
            try {
                swapService.approveTokenTransferToFillSwap(
                    swapToFill = swap,
                    approveTokenTransferToFillSwapTransaction = approveTokenTransferToFillSwapTransaction,
                )
                logger.info("approveTokenTransferToFillSwap: successfully approved transfer for ${swap.id}")
                withContext(Dispatchers.Main) {
                    swap.approvingToFillState.value = TokenTransferApprovalState.AWAITING_TRANSACTION_CONFIRMATION
                }
            } catch (exception: Exception) {
                logger.error("approveTokenTransferToFillSwap: got exception during call for ${swap.id}")
                withContext(Dispatchers.Main) {
                    swap.approvingToFillException = exception
                    swap.approvingToFillState.value = TokenTransferApprovalState.EXCEPTION
                }
            }
        }
    }

    /**
     * Attempts to create a [RawTransaction] that can fill [swap] (which should be a maker-as-seller swap made by the
     * user of this interface) by calling
     * [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap).
     *
     * This passes [swap] to [swapService]'s [SwapService.createFillSwapTransaction] and then passes the resulting
     * transaction to [createdTransactionHandler] or exception to [exceptionHandler].
     *
     * @param swap The [Swap] to be filled.
     * @param createdTransactionHandler A lambda that will accept and handle the created [RawTransaction].
     * @param exceptionHandler A lambda that will accept and handle any exception that occurs during the transaction
     * creation process.
     */
    override fun createFillSwapTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {
        viewModelScope.launch {
            logger.info("createFillSwapTransaction: creating for ${swap.id}")
            try {
                val createdTransaction = swapService.createFillSwapTransaction(
                    swap = swap
                )
                withContext(Dispatchers.Main) {
                    createdTransactionHandler(createdTransaction)
                }
            } catch (exception: Exception) {
                withContext(Dispatchers.Main) {
                    exceptionHandler(exception)
                }
            }
        }
    }

    /**
     * Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     *
     * This clears the swap-filling-related [Exception] of [swap] and sets [swap]'s [Swap.fillingSwapState] to
     * [FillingSwapState.VALIDATING], and then passes all data to [swapService]'s [SwapService.fillSwap] function.
     *
     * @param swap The [Swap] to be filled.
     * @param swapFillingTransaction An optional [RawTransaction] can fill [swap].
     */
    override fun fillSwap(
        swap: Swap,
        swapFillingTransaction: RawTransaction?
    ) {
        swap.fillingSwapException = null
        swap.fillingSwapState.value = FillingSwapState.VALIDATING
        viewModelScope.launch {
            logger.info("fillSwap: filling ${swap.id}")
            try {
                swapService.fillSwap(
                    swap = swap,
                    swapFillingTransaction = swapFillingTransaction,
                )
                logger.info("fillSwap: successfully sent transaction for ${swap.id}")
            } catch (exception: Exception) {
                logger.error("fillSwap: got error during call for ${swap.id}", exception)
                withContext(Dispatchers.Main) {
                    swap.fillingSwapException = exception
                    swap.fillingSwapState.value = FillingSwapState.EXCEPTION
                }
            }
        }
    }

    /**
     * Attempts to report that a buyer has sent fiat payment for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the buyer in
     * [swap].
     *
     * @param swap The [Swap] for which to report sending payment.
     */
    @Deprecated("Use the new transaction pipeline with improved transaction state management")
    override fun reportPaymentSent(swap: Swap) {
        /*
        viewModelScope.launch {
            setReportingPaymentSentState(
                swap = swap,
                state = ReportingPaymentSentState.CHECKING
            )
            try {
                logger.info("reportPaymentSent: reporting for ${swap.id}")
                swapService.reportPaymentSent(
                    swap = swap,
                    afterPossibilityCheck = {
                        setReportingPaymentSentState(
                            swap = swap,
                            state = ReportingPaymentSentState.REPORTING,
                        )
                    },
                )
                logger.info("reportPaymentSent: successfully reported for ${swap.id}")
                setReportingPaymentSentState(
                    swap = swap,
                    state = ReportingPaymentSentState.COMPLETED
                )
            } catch (exception: Exception) {
                logger.error("reportPaymentSent: got exception during reportPaymentSent call for ${swap.id}", exception)
                swap.reportingPaymentSentException = exception
                setReportingPaymentSentState(
                    swap = swap,
                    state = ReportingPaymentSentState.EXCEPTION
                )
            }
        }*/
    }

    /**
     * Attempts to create a [RawTransaction] to call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for
     * [swap], for which the user of this interface should be the buyer.
     *
     * This passes [swap] to [SwapService.createReportPaymentSentTransaction] and then passes the resulting transaction
     * to [createdTransactionHandler] or [Exception] to [exceptionHandler].
     *
     * @param swap The [Swap] for which
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be
     * called.
     * @param createdTransactionHandler A lambda that will accept and handle the created [RawTransaction].
     * @param exceptionHandler A lambda that will accept and handle any exception that occurs during the transaction
     * creation process.
     */
    override fun createReportPaymentSentTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit,
    ) {
        viewModelScope.launch {
            logger.info("createReportPaymentSentTransaction: creating for ${swap.id}")
            try {
                val createdTransaction = swapService.createReportPaymentSentTransaction(
                    swap = swap,
                )
                createdTransactionHandler(createdTransaction)
            } catch (exception: Exception) {
                exceptionHandler(exception)
            }
        }
    }

    /**
     * Attempts to call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface
     * is the buyer.
     *
     * This clears the reporting-payment-sent-related [Exception] of [swap] and sets [swap]'s
     * [Swap.reportingPaymentSentState] to [ReportingPaymentSentState.VALIDATING], and then passes all data to
     * [swapService]'s [SwapService.reportPaymentSent] function.
     *
     * @param swap The [Swap] for which
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be
     * called.
     * @param reportPaymentSentTransaction An optional [RawTransaction] that will call
     * [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for
     * [swap].
     */
    override fun reportPaymentSent(swap: Swap, reportPaymentSentTransaction: RawTransaction?) {
        swap.reportingPaymentSentException = null
        swap.reportingPaymentSentState.value = ReportingPaymentSentState.VALIDATING
        viewModelScope.launch {
            logger.info("reportPaymentSent: reporting for ${swap.id}")
            try {
                swapService.reportPaymentSent(
                    swap = swap,
                    reportPaymentSentTransaction = reportPaymentSentTransaction,
                )
                logger.info("reportPaymentSent: successfully broadcast transaction for ${swap.id}")
            } catch (exception: Exception) {
                logger.error("reportPaymentSent: got exception during reportPaymentSent call for ${swap.id}", exception)
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentSentException = exception
                    swap.reportingPaymentSentState.value = ReportingPaymentSentState.EXCEPTION
                }
            }
        }
    }

    /**
     * Attempts to report that a seller has received fiat payment for a
     * [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the seller
     * in [swap].
     *
     * @param swap The [Swap] for which to report receiving payment.
     */
    override fun reportPaymentReceived(swap: Swap) {
        /*
        viewModelScope.launch {
            setReportingPaymentReceivedState(
                swap = swap,
                state = ReportingPaymentReceivedState.CHECKING
            )
            try {
                logger.info("reportPaymentReceived: reporting for ${swap.id}")
                swapService.reportPaymentReceived(
                    swap = swap,
                    afterPossibilityCheck = {
                        setReportingPaymentReceivedState(
                            swap = swap,
                            state = ReportingPaymentReceivedState.REPORTING,
                        )
                    },
                )
                logger.info("reportPaymentReceived: successfully reported for ${swap.id}")
                setReportingPaymentReceivedState(
                    swap = swap,
                    state = ReportingPaymentReceivedState.COMPLETED
                )
            } catch (exception: Exception) {
                logger.error("reportPaymentReceived: got exception during reportPaymentReceived call for ${swap.id}",
                    exception)
                swap.reportingPaymentReceivedException = exception
                setReportingPaymentReceivedState(
                    swap = swap,
                    state = ReportingPaymentReceivedState.EXCEPTION
                )
            }
        }*/
    }

    /**
     * Attempts to create a [RawTransaction] to call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for [swap], for which the user of this interface should be the seller.
     *
     * This passes [swap] to [SwapService.createReportPaymentReceivedTransaction] and then passes the resulting
     * transaction to [createdTransactionHandler] or [Exception] to [exceptionHandler].
     *
     * @param swap The [Swap] for which
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * will be called.
     * @param createdTransactionHandler A lambda that will accept and handle the created [RawTransaction].
     * @param exceptionHandler A lambda that will accept and handle any exception that occurs during the transaction
     * creation process.
     */
    override fun createReportPaymentReceivedTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit,
    ) {
        viewModelScope.launch {
            logger.info("createReportPaymentReceivedTransaction: creating for ${swap.id}")
            try {
                val createdTransaction = swapService.createReportPaymentReceivedTransaction(
                    swap = swap,
                )
                createdTransactionHandler(createdTransaction)
            } catch (exception: Exception) {
                exceptionHandler(exception)
            }
        }
    }

    /**
     * Attempts to call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this
     * interface is the buyer.
     *
     * This clears the reporting-payment-received-related [Exception] of [swap] and sets [swap]'s
     * [Swap.reportingPaymentReceivedState] to [ReportingPaymentReceivedState.VALIDATING], and then passes all data to
     * [swapService]'s [SwapService.reportPaymentReceived] function.
     *
     * @param swap The [Swap] for which
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * will be called.
     * @param reportPaymentReceivedTransaction An optional [RawTransaction] that will call
     * [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     * for [swap].
     */
    override fun reportPaymentReceived(swap: Swap, reportPaymentReceivedTransaction: RawTransaction?) {
        swap.reportingPaymentReceivedException = null
        swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.VALIDATING
        viewModelScope.launch {
            logger.info("reportPaymentReceived: reporting for ${swap.id}")
            try {
                swapService.reportPaymentReceived(
                    swap = swap,
                    reportPaymentReceivedTransaction = reportPaymentReceivedTransaction,
                )
                logger.info("reportPaymentReceived: successfully broadcast transaction for ${swap.id}")
            } catch (exception: Exception) {
                logger.error("reportPaymentReceived: got exception during reportPaymentReceived call for ${swap.id}",
                    exception)
                withContext(Dispatchers.Main) {
                    swap.reportingPaymentReceivedException = exception
                    swap.reportingPaymentReceivedState.value = ReportingPaymentReceivedState.EXCEPTION
                }
            }
        }
    }

    /**
     * Attempts to close a swap [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     *
     * @param swap The [Swap] to close.
     */
    override fun closeSwap(swap: Swap) {
        /*
        viewModelScope.launch {
            setClosingSwapState(
                swap = swap,
                state = ClosingSwapState.CHECKING,
            )
            try {
                logger.info("closeSwap: closing ${swap.id}")
                swapService.closeSwap(
                    swap = swap,
                    afterPossibilityCheck = {
                        setClosingSwapState(
                            swap = swap,
                            state = ClosingSwapState.CLOSING,
                        )
                    }
                )
                logger.info("closeSwap: successfully closed ${swap.id}")
                setClosingSwapState(
                    swap = swap,
                    state = ClosingSwapState.CHECKING,
                )
            } catch (exception: Exception) {
                logger.error("closeSwap: got exception during closeSwap call for ${swap.id}", exception)
                swap.closingSwapException = exception
                setClosingSwapState(
                    swap = swap,
                    state = ClosingSwapState.EXCEPTION
                )
            }
        }*/
    }

    /**
     * Attempts to create a [RawTransaction] to call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * for [swap].
     *
     * This passes [swap] to [SwapService.createCloseSwapTransaction] and then passes the resulting transaction to
     * [createdTransactionHandler] or [Exception] to [exceptionHandler].
     *
     * @param swap The [Swap] for which
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
     * @param createdTransactionHandler A lambda that will accept and handle the created [RawTransaction].
     * @param exceptionHandler A lambda that will accept and handle any exception that occurs during the transaction
     * creation process.
     */
    override fun createCloseSwapTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit,
    ) {
        viewModelScope.launch {
            logger.info("createCloseSwapTransaction: creating for ${swap.id}")
            try {
                val createdTransaction = swapService.createCloseSwapTransaction(
                    swap = swap
                )
                createdTransactionHandler(createdTransaction)
            } catch (exception: Exception) {
                exceptionHandler(exception)
            }
        }
    }

    /**
     * Attempts to call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) involving the user of this
     * interface.
     *
     * This clears the reporting-payment-received-related [Exception] of [swap] and sets [swap]'s
     * [Swap.closingSwapState] to [ClosingSwapState.VALIDATING], and then passes all data to [swapService]'s
     * [SwapService.closeSwap] function.
     *
     * @param swap The [Swap] for which
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
     * @param closeSwapTransaction An optional [RawTransaction] that will call
     * [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     * for [swap].
     */
    override fun closeSwap(swap: Swap, closeSwapTransaction: RawTransaction?) {
        swap.closingSwapException = null
        swap.closingSwapState.value = ClosingSwapState.VALIDATING
        viewModelScope.launch {
            logger.info("closeSwap: closing ${swap.id}")
            try {
                swapService.closeSwap(
                    swap = swap,
                    closeSwapTransaction = closeSwapTransaction,
                )
                logger.info("closeSwap: successfully broadcast transaction for ${swap.id}")
            } catch (exception: Exception) {
                logger.error("closeSwap: got exception during closeSwap call for ${swap.id}", exception)
                withContext(Dispatchers.Main) {
                    swap.closingSwapException = exception
                    swap.closingSwapState.value = ClosingSwapState.EXCEPTION
                }
            }
        }
    }

}
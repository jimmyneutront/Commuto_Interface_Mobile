package com.commuto.interfacemobile.android.ui.swap

import androidx.compose.runtime.snapshots.SnapshotStateMap
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.swap.Swap
import com.commuto.interfacemobile.android.ui.offer.UIOfferTruthSource
import org.web3j.crypto.RawTransaction
import java.util.*

/**
 * A [UISwapTruthSource] implementation used for previewing user interfaces.
 *
 * @property swaps A [SnapshotStateMap] mapping  [UUID]s to [Swap]s, which acts as a single source of truth for all
 * swap-related data.
 */
class PreviewableSwapTruthSource : UISwapTruthSource {
    override var swaps = SnapshotStateMap<UUID, Swap>().also { map ->
        Swap.sampleSwaps.map {
            map[it.id] = it
        }
    }

    /**
     * Does nothing, since this class is only used for previewing user interfaces.
     */
    override fun addSwap(swap: Swap) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun fillSwap(swap: Swap) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun reportPaymentSent(swap: Swap) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun createReportPaymentSentTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun reportPaymentSent(swap: Swap, reportPaymentSentTransaction: RawTransaction?) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun reportPaymentReceived(swap: Swap) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun createReportPaymentReceivedTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun reportPaymentReceived(swap: Swap, reportPaymentReceivedTransaction: RawTransaction?) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun closeSwap(swap: Swap) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun createCloseSwapTransaction(
        swap: Swap,
        createdTransactionHandler: (RawTransaction) -> Unit,
        exceptionHandler: (Exception) -> Unit
    ) {}

    /**
     * Not used since this class is for previewing user interfaces, but required for adoption of [UISwapTruthSource].
     */
    override fun closeSwap(swap: Swap, closeSwapTransaction: RawTransaction?) {}
}
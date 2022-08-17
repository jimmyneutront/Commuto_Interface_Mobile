package com.commuto.interfacemobile.android.offer

import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.snapshots.SnapshotStateMap
import com.commuto.interfacemobile.android.swap.Swap
import com.commuto.interfacemobile.android.swap.SwapTruthSource
import java.util.*

/**
 * A basic [SwapTruthSource] implementation for testing.
 */
class TestSwapTruthSource: SwapTruthSource {
    override var swaps: SnapshotStateMap<UUID, Swap> = mutableStateMapOf()
    override fun addSwap(swap: Swap) {
        swaps[swap.id] = swap
    }
}
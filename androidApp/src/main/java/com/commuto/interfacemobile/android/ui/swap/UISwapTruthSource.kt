package com.commuto.interfacemobile.android.ui.swap

import com.commuto.interfacemobile.android.swap.Swap
import com.commuto.interfacemobile.android.swap.SwapTruthSource

/**
 * An interface that a class must adopt in order to act as a single source of truth for swap-related data in an
 * application with a graphical user interface.
 */
interface UISwapTruthSource: SwapTruthSource {
    /**
     * Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     *
     * @param swap The [Swap] to fill.
     */
    fun fillSwap(
        swap: Swap
    )
}
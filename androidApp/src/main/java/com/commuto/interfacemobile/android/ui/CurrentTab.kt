package com.commuto.interfacemobile.android.ui

import com.commuto.interfacemobile.android.ui.offer.OffersComposable
import com.commuto.interfacemobile.android.ui.swap.SwapsComposable

/**
 * Indicates which tab view should be displayed to the user.
 *
 * @property OFFERS Indicates that [OffersComposable] should be displayed to the user.
 * @property SWAPS Indicates that [SwapsComposable] should be displayed to the user.
 */
enum class CurrentTab {
    OFFERS,
    SWAPS;
}
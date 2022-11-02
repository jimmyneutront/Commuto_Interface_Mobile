package com.commuto.interfacemobile.android

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material.Divider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.ui.CurrentTab
import com.commuto.interfacemobile.android.ui.offer.OffersViewModel
import com.commuto.interfacemobile.android.ui.TabButton
import com.commuto.interfacemobile.android.ui.offer.OffersComposable
import com.commuto.interfacemobile.android.ui.settlement.SettlementMethodViewModel
import com.commuto.interfacemobile.android.ui.settlement.SettlementMethodsComposable
import com.commuto.interfacemobile.android.ui.swap.SwapViewModel
import com.commuto.interfacemobile.android.ui.swap.SwapsComposable
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * The main Activity and entry point into the application.
 *
 * @property offersViewModel The [OffersViewModel] that acts as a single source of truth for all offer-related data.
 * @property swapViewModel The [SwapViewModel] that acts as a single source of truth for all swap-related data.
 */
@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject
    lateinit var offersViewModel: OffersViewModel

    @Inject
    lateinit var swapViewModel: SwapViewModel

    @Inject
    lateinit var settlementMethodViewModel: SettlementMethodViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val currentTab = remember { mutableStateOf(CurrentTab.OFFERS) }
            Column(
                verticalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxHeight()
            ) {
                Box {
                    when (currentTab.value) {
                        CurrentTab.OFFERS -> {
                            OffersComposable(
                                offerTruthSource = offersViewModel,
                            )
                        }
                        CurrentTab.SWAPS -> {
                            SwapsComposable(
                                swapTruthSource = swapViewModel
                            )
                        }
                        CurrentTab.SETTLEMENT_METHODS -> {
                            SettlementMethodsComposable(
                                settlementMethodViewModel = settlementMethodViewModel
                            )
                        }
                    }
                }
                Column {
                    Divider(
                        thickness = 1.dp
                    )
                    Row(
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp)
                    ) {
                        TabButton(
                            label = "Offers",
                            onClick = { currentTab.value = CurrentTab.OFFERS }
                        )
                        TabButton(
                            label = "Swaps",
                            onClick = { currentTab.value = CurrentTab.SWAPS }
                        )
                        TabButton(
                            label = "SM",
                            onClick = {currentTab.value = CurrentTab.SETTLEMENT_METHODS}
                        )
                    }
                }
            }
        }
    }
}

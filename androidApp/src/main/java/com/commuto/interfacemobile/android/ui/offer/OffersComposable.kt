package com.commuto.interfacemobile.android.ui.offer

import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.commuto.interfacemobile.android.ui.settlement.PreviewableSettlementMethodTruthSource
import com.commuto.interfacemobile.android.ui.settlement.UISettlementMethodTruthSource
import java.math.BigInteger
import java.util.*

/**
 * Contains the [NavHost] for offers and displays the [Composable] to which the user has navigated.
 *
 * @param offerTruthSource An object implementing [UIOfferTruthSource] that acts as a single source of truth for all
 * offer-related data.
 * @param settlementMethodTruthSource An object implementing [UISettlementMethodTruthSource] that acts as a single
 * source of truth for all settlement-method-related data.
 */
@Composable
fun OffersComposable(
    offerTruthSource: UIOfferTruthSource,
    settlementMethodTruthSource: UISettlementMethodTruthSource
) {

    val navController = rememberNavController()

    // This should take up the entire height of the screen minus 50 dp, to display the bottom navigation bar.
    NavHost(
        navController = navController,
        startDestination = "OffersListComposable",
        modifier = Modifier.height((LocalConfiguration.current.screenHeightDp - 50).dp)
    ) {
        composable("OffersListComposable") {
            OffersListComposable(offerTruthSource, navController)
        }
        composable(
            "OpenOfferComposable",
        ) {
            OpenOfferComposable(
                offerTruthSource = offerTruthSource,
                settlementMethodTruthSource = settlementMethodTruthSource,
                chainID = BigInteger.valueOf(31337L)
            )
        }
        composable(
            "OfferComposable/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType })
        ) { backStackEntry ->
            val id = try { UUID.fromString(backStackEntry.arguments?.getString("id")) }
            catch (e: Throwable) { null }
            OfferComposable(offerTruthSource, id, navController = navController)
        }
        composable(
            "EditOfferComposable/{id}/{stablecoinCurrencyCode}",
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("stablecoinCurrencyCode") { type = NavType.StringType },
            )
        ) { backStackEntry ->
            val id = try { UUID.fromString(backStackEntry.arguments?.getString("id")) }
            catch (e: Throwable) { null }
            val stablecoinCurrencyCode = backStackEntry.arguments?.getString("stablecoinCurrencyCode")
                ?: "Unknown Stablecoin"
            EditOfferComposable(
                offer = offerTruthSource.offers[id],
                offerTruthSource = offerTruthSource,
                settlementMethodTruthSource = settlementMethodTruthSource,
                stablecoinCurrencyCode = stablecoinCurrencyCode
            )
        }
    }
}

/**
 * Displays a preview of [OffersComposable].
 */
@Preview
@Composable
fun PreviewOffersComposable() {
    OffersComposable(
        PreviewableOfferTruthSource(),
        PreviewableSettlementMethodTruthSource(),
    )
}
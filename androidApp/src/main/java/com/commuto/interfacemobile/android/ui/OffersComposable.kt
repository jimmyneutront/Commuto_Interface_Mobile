package com.commuto.interfacemobile.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import java.math.BigInteger
import java.util.*

/**
 * Contains the [NavHost] for offers and displays the [Composable] to which the user has navigated.
 *
 * @param offerTruthSource An object implementing [UIOfferTruthSource] that acts as a single source of truth for all
 * offer-related data.
 */
@Composable
fun OffersComposable(offerTruthSource: UIOfferTruthSource) {

    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "OffersListComposable") {
        composable("OffersListComposable") {
            OffersListComposable(offerTruthSource, navController)
        }
        composable(
            "OpenOfferComposable",
        ) {
            OpenOfferComposable(
                offerTruthSource = offerTruthSource,
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
    OffersComposable(PreviewableOfferTruthSource())
}
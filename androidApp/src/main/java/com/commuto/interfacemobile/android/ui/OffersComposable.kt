package com.commuto.interfacemobile.android.ui

import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.commuto.interfacemobile.android.offer.OfferTruthSource
import com.commuto.interfacemobile.android.offer.PreviewableOfferTruthSource

/**
 * Contains the [NavHost] for offers and displays the [Composable] to which the user has navigated.
 *
 * @param offerTruthSource An object implementing [OfferTruthSource] that acts as a single source of truth for all
 * offer-related data.
 */
@Composable
fun OffersComposable(offerTruthSource: OfferTruthSource) {

    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "OffersListComposable") {
        composable("OffersListComposable") {
            OffersListComposable(offerTruthSource, navController)
        }
        composable(
            "OfferDetailComposable/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType })
        ) { backStackEntry ->
            Text("id: " + backStackEntry.arguments?.getString("id"))
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
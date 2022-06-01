package com.commuto.interfacemobile.android.ui

import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.commuto.interfacemobile.android.offer.OfferService

@Composable
fun OffersComposable(viewModel: OffersViewModel) {

    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "OffersListComposable") {
        composable("OffersListComposable") {
            OffersListComposable(viewModel, navController)
        }
        composable(
            "OfferDetailComposable/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType })
        ) { backStackEntry ->
            Text("id: " + backStackEntry.arguments?.getString("id"))
        }
    }
}

@Preview
@Composable
fun PreviewOffersComposable() {
    OffersComposable(OffersViewModel(OfferService()))
}
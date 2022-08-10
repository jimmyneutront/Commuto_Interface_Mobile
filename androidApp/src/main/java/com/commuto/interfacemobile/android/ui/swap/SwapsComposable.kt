package com.commuto.interfacemobile.android.ui.swap

import androidx.compose.foundation.layout.height
import androidx.compose.material.Text
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

/**
 * Contains the [NavHost] for swaps and displays the [Composable] to which the user has navigated.
 */
@Composable
fun SwapsComposable() {

    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = "SwapsListComposable",
        modifier = Modifier.height((LocalConfiguration.current.screenHeightDp - 50).dp)
    ) {
        composable("SwapsListComposable") {
            SwapsListComposable(
                navController = navController
            )
        }
        composable(
            "SwapComposable/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType })
        ) { backStackEntry ->
            val idString = backStackEntry.arguments?.getString("id") ?: "No ID specified"
            Text(idString)
        }
    }
}

/**
 * Displays a preview of [SwapsComposable].
 */
@Preview
@Composable
fun PreviewSwapsComposable() {
    SwapsComposable()
}
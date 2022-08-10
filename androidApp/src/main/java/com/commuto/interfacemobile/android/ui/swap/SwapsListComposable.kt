package com.commuto.interfacemobile.android.ui.swap

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import com.commuto.interfacemobile.android.swap.Swap

/**
 * Displays a list containing a [SwapCardComposable]-labeled [Button] for each swap in [Swap.sampleSwaps] that navigates
 * to "SwapComposable/ + swap id as a [String]" when pressed.
 *
 * @param navController The [NavController] that controls navigation between swap-related [Composable]s.
 */
@Composable
fun SwapsListComposable(
    navController: NavController
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Swaps",
                style = MaterialTheme.typography.h2,
                fontWeight = FontWeight.Bold,
            )
        }
        Divider(
            modifier = Modifier.padding(horizontal = 10.dp),
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.2f),
        )
        LazyColumn {
            for (swap in Swap.sampleSwaps) {
                item {
                    Button(
                        onClick = {
                            navController.navigate("SwapComposable/" + swap.id.toString())
                        },
                        border = BorderStroke(1.dp, Color.Black),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color.Transparent
                        ),
                        modifier = Modifier
                            .padding(PaddingValues(top = 5.dp))
                            .padding(horizontal = 5.dp),
                        contentPadding = PaddingValues(10.dp),
                        elevation = null,
                    ) {
                        SwapCardComposable(
                            swapDirection = swap.direction.string,
                            stablecoinCode = "STBL"
                        )
                    }
                }
            }
        }
    }
}

/**
 * Displays a preview of [SwapsListComposable].
 */
@Preview(
    showBackground = true,
    heightDp = 600,
    widthDp = 375,
)
@Composable
fun PreviewSwapsListComposable() {
    SwapsListComposable(
        rememberNavController()
    )
}
package com.commuto.interfacemobile.android.ui.settlement

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.commuto.interfacemobile.android.settlement.SettlementMethod
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateSEPAData
import com.commuto.interfacemobile.android.settlement.privatedata.PrivateSWIFTData
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Displays the list of the user's settlement methods as [SettlementMethodCardComposable]s in a [LazyColumn].
 */
@Composable
fun SettlementMethodsComposable() {

    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = "SettlementMethodsListComposable",
        modifier = Modifier.height((LocalConfiguration.current.screenHeightDp - 50).dp)
    ) {
        composable("SettlementMethodsListComposable") {
            Column {
                Box {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Settlement Methods",
                            style = MaterialTheme.typography.h2,
                            fontWeight = FontWeight.Bold,
                        )
                        Button(
                            onClick = {},
                            content = {
                                Text(
                                    text = "Add",
                                    fontWeight = FontWeight.Bold,
                                )
                            },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = Color.Transparent,
                                contentColor = Color.Black,
                            ),
                            elevation = null
                        )
                    }
                }
                Divider(
                    modifier = Modifier.padding(horizontal = 10.dp),
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.2f),
                )
                LazyColumn {
                    for (entry in SettlementMethod.sampleSettlementMethodsEmptyPrices) {
                        item {
                            Button(
                                onClick = {},
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
                                SettlementMethodCardComposable(settlementMethod = entry)
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * A card displaying basic information about a settlement method belonging to the user, to be shown in the list of the
 * user's settlement methods.
 * @param settlementMethod The [SettlementMethod] about which information will be displayed.
 */
@Composable
fun SettlementMethodCardComposable(settlementMethod: SettlementMethod) {
    val detailString = createDetailString(settlementMethod = settlementMethod)
    Column(
        horizontalAlignment = Alignment.Start,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = settlementMethod.method,
            fontWeight = FontWeight.Bold
        )
        Text(settlementMethod.currency)
        Text(
            text = detailString,
            style = MaterialTheme.typography.subtitle1
        )
    }
}

fun createDetailString(settlementMethod: SettlementMethod): String {
    val privateDataString = settlementMethod.privateData
    val detailString = privateDataString ?: "Unable to parse data"
    if (privateDataString != null) {
        try {
            val privateSEPAData = Json.decodeFromString<PrivateSEPAData>(privateDataString)
            return "IBAN: ${privateSEPAData.iban}"
        } catch (exception: Exception) {}
        try {
            val privateSWIFTData = Json.decodeFromString<PrivateSWIFTData>(settlementMethod.privateData ?: "")
            return "Account: ${privateSWIFTData.accountNumber}"
        } catch (exception: Exception) {}
    }
    return detailString
}

@Preview(
    showBackground = true,
    heightDp = 600,
    widthDp = 375,
)
@Composable
fun PreviewSettlementMethodsComposable() {
    SettlementMethodsComposable()
}
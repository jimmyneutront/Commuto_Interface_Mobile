package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.SettlementMethod

/**
 * Allows the user to edit one of their [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)s.
 *
 * @param stablecoinCurrencyCode The currency code of the offer's stablecoin.
 */
@Composable
fun EditOfferComposable(
    stablecoinCurrencyCode: String
) {

    val settlementMethods = remember { SettlementMethod.sampleSettlementMethodsEmptyPrices }
    val selectedSettlementMethods = remember { mutableStateListOf<SettlementMethod>() }

    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
            .padding(9.dp)
    ) {
        Text(
            text = "Edit Offer",
            style = MaterialTheme.typography.h3,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Settlement Methods:",
            style =  MaterialTheme.typography.h6,
        )
        SettlementMethodSelector(
            settlementMethods = settlementMethods,
            stablecoinCurrencyCode = stablecoinCurrencyCode,
            selectedSettlementMethods = selectedSettlementMethods
        )
        Button(
            onClick = {

            },
            content = {
                Text(
                    text = "Edit Offer",
                    style = MaterialTheme.typography.h4,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            },
            border = BorderStroke(3.dp, Color.Black),
            colors = ButtonDefaults.buttonColors(
                backgroundColor =  Color.Transparent,
                contentColor = Color.Black,
            ),
            elevation = null,
            modifier = Modifier.width(400.dp),
        )
    }

}

/**
 * Displays a preview of [EditOfferComposable] with the stablecoin currency code "STBL".
 */
@Preview(
    showBackground = true,
)
@Composable
fun PreviewEditOfferComposable() {
    EditOfferComposable(
        stablecoinCurrencyCode = "STBL"
    )
}

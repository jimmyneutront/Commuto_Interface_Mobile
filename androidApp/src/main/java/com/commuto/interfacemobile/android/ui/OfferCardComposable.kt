package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.Offer

/**
 * Displays a card with basic information about an offer, to be shown in the main list of open
 * offers.
 *
 * @param offer The offer for which this card displays basic information.
 */
@Composable
fun OfferCardComposable(offer: Offer) {
    Box {
        Row {
            Column {
                Text(
                    text = offer.direction,
                    style = MaterialTheme.typography.h5,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(5.dp))
                Text(
                    text = offer.price + " " + offer.pair,
                    style = MaterialTheme.typography.h5
                )
            }
            Spacer(modifier = Modifier.fillMaxWidth())
        }
    }
}

/**
 * Displays a preview of [OfferCardComposable] with a sample [Offer].
 */
@Preview(
    showBackground = true,
)
@Composable
fun PreviewOfferCardComposable() {
    OfferCardComposable(
        offer = Offer.sampleOffers[0],
    )
}
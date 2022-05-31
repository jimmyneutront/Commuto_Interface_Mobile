package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.Divider
import androidx.compose.material.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.Offer

@Composable
fun OffersComposable(offers: List<Offer>) {
    OffersDividerComposable()
    LazyColumn {
        items(offers) { offer ->
            OfferCardComposable(offer, Modifier.padding(10.dp))
            OffersDividerComposable()
        }
    }
}

@Composable
private fun OffersDividerComposable() {
    Divider(
        modifier = Modifier.padding(horizontal = 10.dp),
        color = MaterialTheme.colors.onSurface.copy(alpha = 0.2f),
    )
}

@Preview
@Composable
fun PreviewOffersComposable() {
    OffersComposable(Offer.sampleOffers)
}
package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import com.commuto.interfacemobile.android.offer.Offer

@Composable
fun OffersListComposable(offers: List<Offer>, navController: NavController) {
    Column {
        Text(
            text = "Offers",
            style = MaterialTheme.typography.h2,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 10.dp)
        )
        OffersDividerComposable()
        LazyColumn {
            items(offers) { offer ->
                Button(
                    colors = ButtonDefaults.buttonColors(backgroundColor = Color.Transparent),
                    contentPadding = PaddingValues(10.dp),
                    onClick = {
                        navController.navigate("OfferDetailComposable/" + offer.id.toString())
                    }
                ) {
                    OfferCardComposable(offer)
                }
                OffersDividerComposable()
            }
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

@Preview(
    showBackground = true,
)
@Composable
fun PreviewOffersListComposable() {
    OffersListComposable(Offer.sampleOffers, rememberNavController())
}
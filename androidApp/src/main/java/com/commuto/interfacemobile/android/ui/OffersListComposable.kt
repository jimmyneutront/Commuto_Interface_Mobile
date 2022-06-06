package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.compose.rememberNavController
import com.commuto.interfacemobile.android.R
import com.commuto.interfacemobile.android.offer.OfferService

@Composable
fun OffersListComposable(viewModel: OffersViewModel, navController: NavController) {
    Column {
        Text(
            text = stringResource(R.string.offers),
            style = MaterialTheme.typography.h2,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 10.dp)
        )
        OffersDividerComposable()
        if (viewModel.offerService.offers.size == 0) {
            OffersNoneFoundComposable()
        } else {
            LazyColumn {
                items(viewModel.offerService.offers) { offer ->
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
}

@Composable
private fun OffersDividerComposable() {
    Divider(
        modifier = Modifier.padding(horizontal = 10.dp),
        color = MaterialTheme.colors.onSurface.copy(alpha = 0.2f),
    )
}

@Composable
private fun OffersNoneFoundComposable() {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.fillMaxSize()
    ) {
        Text(
            text = stringResource(R.string.no_offers_found),
            style = MaterialTheme.typography.body1,
            modifier = Modifier.padding(horizontal = 10.dp)
        )
    }
}

@Preview(
    showBackground = true,
    heightDp = 600,
)
@Composable
fun PreviewOffersListComposable() {
    OffersListComposable(OffersViewModel(OfferService()), rememberNavController())
}
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
import com.commuto.interfacemobile.android.offer.OfferTruthSource
import com.commuto.interfacemobile.android.offer.PreviewableOfferTruthSource

/**
 * Displays a [OffersNoneFoundComposable] if there are no open offers in [offerTruthSource], or, if there
 * are open offers in [offerTruthSource], displays a list containing an [OfferCardComposable]-labeled
 * [Button] for each open offer in [offerTruthSource] that navigates to "OfferDetailComposable/ + offer id
 * as a [String]" when pressed.
 *
 * @param offerTruthSource The OffersViewModel that acts as a single source of truth for all offer-related data.
 * @param navController The [NavController] that controls navigation between offer-related [Composable]s.
 */
@Composable
fun OffersListComposable(offerTruthSource: OfferTruthSource, navController: NavController) {
    Column {
        Text(
            text = stringResource(R.string.offers),
            style = MaterialTheme.typography.h2,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 10.dp)
        )
        OffersDividerComposable()
        if (offerTruthSource.offers.size == 0) {
            OffersNoneFoundComposable()
        } else {
            LazyColumn {
                items(offerTruthSource.offers) { offer ->
                    Button(
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color.Transparent),
                        contentPadding = PaddingValues(10.dp),
                        onClick = {
                            navController.navigate("OfferComposable/" + offer.id.toString())
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

/**
 * Displays a horizontal divider.
 */
@Composable
private fun OffersDividerComposable() {
    Divider(
        modifier = Modifier.padding(horizontal = 10.dp),
        color = MaterialTheme.colors.onSurface.copy(alpha = 0.2f),
    )
}

/**
 * Displays the vertically and horizontally centered words "No Offers Found".
 */
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

/**
 * Displays a preview of [OffersListComposable].
 */
@Preview(
    showBackground = true,
    heightDp = 600,
)
@Composable
fun PreviewOffersListComposable() {
    OffersListComposable(
        PreviewableOfferTruthSource(),
        rememberNavController()
    )
}
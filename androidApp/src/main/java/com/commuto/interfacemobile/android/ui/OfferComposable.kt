package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CutCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.*
import java.math.BigInteger
import java.util.*

/**
 * Displays details about a particular [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 * @param offerTruthSource The OffersViewModel that acts as a single source of truth for all offer-related data.
 * @param id: The ID of the offer about which this [OfferComposable] is displaying information.
 * @param stablecoinInfoRepo The [StablecoinInformationRepository] that this [Composable] uses to get stablecoin name
 * and currency code information. Defaults to [StablecoinInformationRepository.hardhatStablecoinInfoRepo] if no
 * other value is passed.
 */
@Composable
fun OfferComposable(
    offerTruthSource: UIOfferTruthSource,
    id: UUID?,
    stablecoinInfoRepo: StablecoinInformationRepository =
        StablecoinInformationRepository.hardhatStablecoinInfoRepo
) {

    /**
     * The offer about which this [Composable] displays information.
     */
    val offer = offerTruthSource.offers[id]

    if (id == null) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Text(
                text = "This Offer has an invalid ID.",
            )
        }
    } else if (offer == null) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Text(
                text = "This Offer is not available.",
            )
        }
    } else {
        val stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(offer.chainID, offer.stablecoin)
        val settlementMethods = remember { offer.settlementMethods }
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
        ) {
            Column(
                modifier = Modifier.padding(9.dp)
            ) {
                Text(
                    text = "Offer",
                    style = MaterialTheme.typography.h3,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "Direction:",
                    style =  MaterialTheme.typography.h6,
                )
                DisclosureComposable(
                    header = {
                        Text(
                            text = buildDirectionString(offer.direction, stablecoinInformation),
                            style = MaterialTheme.typography.h5,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    content = {
                        Text(buildDirectionDescriptionString(offer.direction.string, stablecoinInformation))
                    }
                )
                OfferAmountComposable(
                    stablecoinInformation,
                    offer.amountLowerBound,
                    offer.amountUpperBound,
                    offer.securityDepositAmount,
                )
            }
            Row(
                modifier = Modifier.offset(x = 9.dp)
            ) {
                Column {
                    SettlementMethodsListComposable(stablecoinInformation, settlementMethods)
                }
            }
            Column(
                modifier = Modifier.padding(9.dp)
            ) {
                DisclosureComposable(
                    header = {
                        Text(
                            text = "Service Fee Rate: ${offer.serviceFeeRate.toDouble() / 100.0}%",
                            style = MaterialTheme.typography.h5,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    content = {
                        Text(
                            "To take this offer, you must pay a fee equal to ${offer.serviceFeeRate.toDouble() 
                                    / 100.0} percent of the amount to be exchanged."
                        )
                    }
                )
                DisclosureComposable(
                    header = {
                        Text(
                            text = "Advanced Details",
                            style = MaterialTheme.typography.h5,
                            fontWeight = FontWeight.Bold
                        )
                    },
                    content = {
                        Column(
                            horizontalAlignment = Alignment.Start
                        ) {
                            Text(
                                text = "Offer ID: $id"
                            )
                            Text(
                                text = "Chain ID: ${offer.chainID}"
                            )
                        }
                    }
                )
            }
        }
    }
}

/**
 * Creates the text for the label of the direction-related [DisclosureComposable].
 *
 * @param direction The offer's direction.
 * @param stablecoinInformation A [StablecoinInformation?] for this offer's stablecoin.
 */
fun buildDirectionString(direction: OfferDirection, stablecoinInformation: StablecoinInformation?): String {
    val stablecoinCode = stablecoinInformation?.currencyCode ?: "Unknown Stablecoin"
    val directionJoiner: String = when (direction) {
        OfferDirection.BUY -> {
            "with"
        }
        OfferDirection.SELL -> {
            "for"
        }
    }
    return "${direction.string} $stablecoinCode $directionJoiner fiat"
}

/**
 * Creates the text for the content of the direction-related [DisclosureComposable]
 *
 * @param directionString The offer's direction in human readable format.
 * @param stablecoinInformation A [StablecoinInformation?] for this offer's stablecoin.
 */
fun buildDirectionDescriptionString(directionString: String, stablecoinInformation: StablecoinInformation?): String {
    val stablecoinName = stablecoinInformation?.name ?: "Unknown Stablecoin"
    return "This is a $directionString offer: the maker of this offer wants to ${directionString.lowercase()} " +
            "$stablecoinName in exchange for fiat."
}

/**
 * Displays the minimum and maximum amount stablecoin that the maker of an
 * [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)  is willing to exchange.
 *
 * @param stablecoinInformation A [StablecoinInformation?] for this offer's stablecoin.
 * @param min The Offer's minimum amount.
 * @param max The Offer's maximum amount.
 * @param securityDeposit The Offer's security deposit amount.
 */
@Composable
fun OfferAmountComposable(
    stablecoinInformation: StablecoinInformation?,
    min: BigInteger,
    max: BigInteger,
    securityDeposit: BigInteger
) {
    val headerString = if (stablecoinInformation != null) "Amount: " else "Amount (in token base units):"
    val currencyCode = stablecoinInformation?.currencyCode ?: "Unknown Stablecoin"
    val minimumString = if (stablecoinInformation != null) min.divide(BigInteger.TEN.pow(stablecoinInformation.decimal))
        .toString() else min.toString()
    val maximumString = if (stablecoinInformation != null) max.divide(BigInteger.TEN.pow(stablecoinInformation.decimal))
        .toString() else min.toString()
    val securityDepositString = if (stablecoinInformation != null) securityDeposit.divide(BigInteger.TEN
        .pow(stablecoinInformation.decimal)).toString() else securityDeposit.toString()
    Text(
        text = headerString,
        style = MaterialTheme.typography.h6
    )
    if (min == max) {
        Text(
            text = "$minimumString $currencyCode",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
    } else {
        Text(
            text = "Minimum: $minimumString $currencyCode",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Maximum: $maximumString $currencyCode",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
    }
    Text(
        text = "Security Deposit: $securityDepositString $currencyCode",
        style = MaterialTheme.typography.h5,
    )
}

/**
 * Displays a horizontally scrolling list of [SettlementMethodComposable]s.
 *
 * @param stablecoinInformation A [StablecoinInformation?] for this offer's stablecoin.
 * @param settlementMethods The settlement methods to be displayed.
 */
@Composable
fun SettlementMethodsListComposable(
    stablecoinInformation: StablecoinInformation?,
    settlementMethods: SnapshotStateList<SettlementMethod>
) {
    val stablecoinCode = stablecoinInformation?.currencyCode ?: "Unknown Stablecoin"
    Text(
        text = "Settlement methods:",
        style = MaterialTheme.typography.h6
    )
    if (settlementMethods.size > 0) {
        LazyRow(
            modifier = Modifier.padding(PaddingValues(vertical = 6.dp))
        ) {
            settlementMethods.forEach {
                item {
                    SettlementMethodComposable(stablecoin = stablecoinCode, settlementMethod = it)
                    Spacer(modifier = Modifier.width(9.dp))
                }
            }
        }
    } else {
        Text(
            text = "No settlement methods found",
            style = MaterialTheme.typography.body1
        )
    }
}

/**
 * Displays a card containing information about a settlement method.
 *
 * @param stablecoin The human readable symbol of the stablecoin for which the offer related to these settlement methods
 * has been made.
 * @param settlementMethod The settlement method that this card displays.
 */
@Composable
fun SettlementMethodComposable(stablecoin: String, settlementMethod: SettlementMethod) {
    Column(
        modifier = Modifier
            .border(width = 1.dp, color = Color.Black, CutCornerShape(0.dp))
            .padding(9.dp)
    ) {
        Text(
            text = buildCurrencyDescription(settlementMethod),
            modifier = Modifier.padding(3.dp)
        )
        Text(
            text = buildPriceDescription(settlementMethod, stablecoin),
            modifier = Modifier.padding(3.dp)
        )
    }
}

/**
 * Builds a human readable [String] describing the currency and transfer method, such as "EUR via SEPA" or
 * "USD via SWIFT".
 *
 * @param settlementMethod: THe settlement method for which the currency description should be built.
 */
fun buildCurrencyDescription(settlementMethod: SettlementMethod): String {
    return "${settlementMethod.currency} via ${settlementMethod.method}"
}

/**
 * Builds a human readable [String] describing the price specified for this settlement method, such as "Price: 0.94
 * EUR/DAI" or "Price: 1.00 USD/USDC"
 *
 * @param settlementMethod: The settlement method for which the currency description should be built.
 * @param stablecoin The human readable symbol of the stablecoin for which the offer related to [settlementMethod] has
 * been made.
 */
fun buildPriceDescription(settlementMethod: SettlementMethod, stablecoin: String): String {
    return "Price: ${settlementMethod.price} ${settlementMethod.currency}/$stablecoin"
}

/**
 * Displays a preview of [OfferComposable] with id equal that of a sample offer for a known stablecoin: Dai.
 */
@Preview(
    showBackground = true
)
@Composable
fun PreviewOfferComposableWithDaiOffer() {
    OfferComposable(PreviewableOfferTruthSource(), Offer.sampleOffers[0].id)
}

/**
 * Displays a preview of [OfferComposable] with id equal that of a sample offer for an unknown stablecoin.
 */
@Preview(
    showBackground = true
)
@Composable
fun PreviewOfferComposableWithUnknownStablecoinOffer() {
    OfferComposable(PreviewableOfferTruthSource(), Offer.sampleOffers[3].id)
}

/**
 * Displays a preview of [OfferComposable] with id equal to a new random UUID.
 */
@Preview(
    showBackground = true
)
@Composable
fun PreviewOfferComposableWithRandomUUID() {
    OfferComposable(PreviewableOfferTruthSource(), UUID.randomUUID())
}

/**
 * Displays a preview of [OfferComposable] with id equal to null.
 */
@Preview(
    showBackground = true,
    widthDp = 300,
    heightDp = 100,
)
@Composable
fun PreviewOfferComposableWithNull() {
    OfferComposable(PreviewableOfferTruthSource(),null)
}
package com.commuto.interfacemobile.android.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.OfferDirection
import com.commuto.interfacemobile.android.offer.SettlementMethod
import java.lang.NumberFormatException
import java.math.BigDecimal
import java.math.BigInteger

/**
 * Used to create new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)s.
 */
@Composable
fun CreateOfferComposable(
    chainID: BigInteger,
    stablecoins: StablecoinInformationRepository = StablecoinInformationRepository.ethereumMainnetStablecoinInfoRepo
) {

    val direction = remember { mutableStateOf<OfferDirection?>(null) }

    val selectedStablecoin = remember { mutableStateOf<String?>(null) }

    val stablecoinCurrencyCode = stablecoins
        .getStablecoinInformation(chainID, selectedStablecoin.value ?: "")?.currencyCode ?: "Stablecoin"

    val minimumAmountString = remember { mutableStateOf("0.00") }

    val minimumAmount = remember { mutableStateOf(BigDecimal.ZERO) }

    val maximumAmountString = remember { mutableStateOf("0.00") }

    val maximumAmount = remember { mutableStateOf(BigDecimal.ZERO) }

    val securityDepositAmountString = remember { mutableStateOf("0.00") }

    val securityDepositAmount = remember { mutableStateOf(BigDecimal.ZERO) }

    val serviceFeeRate = BigInteger.valueOf(100L)

    val settlementMethods = remember { SettlementMethod.sampleSettlementMethodsEmptyPrices }

    val selectedSettlementMethods = remember { mutableStateListOf<SettlementMethod>() }

    Column(
        modifier = Modifier.verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Create Offer",
            style = MaterialTheme.typography.h3,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Direction:",
            style =  MaterialTheme.typography.h6,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
        ) {
            val isBuyDirection = (direction.value == OfferDirection.BUY)
            val isSellDirection = (direction.value == OfferDirection.SELL)
            DirectionButtonComposable(
                isSelected = isBuyDirection,
                text = "Buy",
                onClick = {
                    direction.value = OfferDirection.BUY
                },
                modifier = Modifier.width(195.dp)
            )
            Spacer(
                modifier = Modifier.width(10.dp)
            )
            DirectionButtonComposable(
                isSelected = isSellDirection,
                text = "Sell",
                onClick = {
                    direction.value = OfferDirection.SELL
                },
                modifier = Modifier.width(195.dp)
            )
        }
        Text(
            text = "Stablecoin:",
            style =  MaterialTheme.typography.h6,
        )
        StablecoinListComposable(
            chainID = chainID,
            stablecoins = stablecoins,
            selectedStablecoin = selectedStablecoin
        )
        /*
        If the user sets a minimum amount greater than a maximum amount, set the maximum amount equal to the minimum
        amount
         */
        if (minimumAmount.value > maximumAmount.value) {
            minimumAmount.value = maximumAmount.value
            minimumAmountString.value = minimumAmount.value.toString()
        }
        Text(
            text = "Minimum $stablecoinCurrencyCode Amount:",
            style =  MaterialTheme.typography.h6,
        )
        StablecoinAmountComposable(
            amountString = minimumAmountString,
            amount = minimumAmount
        )
        Text(
            text = "Maximum $stablecoinCurrencyCode Amount:",
            style =  MaterialTheme.typography.h6,
        )
        StablecoinAmountComposable(
            amountString = maximumAmountString,
            amount = maximumAmount
        )
        if (maximumAmount.value > securityDepositAmount.value * BigDecimal.TEN) {
            securityDepositAmount.value = maximumAmount.value.divide(BigDecimal.TEN)
                .setScale(6, BigDecimal.ROUND_UP)
        }
        DisclosureComposable(
            header = {
                Text(
                    text = "Security Deposit $stablecoinCurrencyCode Amount:",
                    style =  MaterialTheme.typography.h6,
                )
            },
            content = {
                Text(
                    text = "The Security Deposit Amount must be at least 10% of the Maximum Amount."
                )
            }
        )
        StablecoinAmountComposable(
            amountString = securityDepositAmountString,
            amount = securityDepositAmount
        )
        DisclosureComposable(
            header = {
                Text(
                    text = "Service Fee Rate:",
                    style =  MaterialTheme.typography.h6,
                )
            },
            content = {
                Text(
                    text = "The percentage of the actual amount of stablecoin exchanged that you will be charged as " +
                            "a service fee."
                )
            }
        )
        Text(
            text = "${BigDecimal(serviceFeeRate).divide(BigDecimal.valueOf(100L)).setScale(2)} %",
            style = MaterialTheme.typography.h4
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
            onClick = {},
            content = {
                Text(
                    text = "Create Offer",
                    style = MaterialTheme.typography.h4,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.width(400.dp),
                    textAlign = TextAlign.Center
                )
            },
            border = BorderStroke(3.dp, Color.Black),
            colors = ButtonDefaults.buttonColors(
                backgroundColor =  Color.Transparent,
                contentColor = Color.Black,
            ),
            elevation = null,
        )
    }
}

/**
 * Displays a button that represents an offer direction.
 */
@Composable
fun DirectionButtonComposable(isSelected: Boolean, text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        content = {
            Text(
                text = text,
                style = MaterialTheme.typography.h4,
                fontWeight = FontWeight.Bold
            )
        },
        border = if (!isSelected) BorderStroke(1.dp, Color.Black) else null,
        colors = ButtonDefaults.buttonColors(
            backgroundColor = if (isSelected) Color.Green else Color.Transparent,
            contentColor = if (isSelected) Color.White else Color.Black,
        ),
        modifier = modifier,
        elevation = null,
    )
}

/**
 * Displays a vertical list of Stablecoin cards, one for each stablecoin with the specified chain ID in the specified
 * [StablecoinInformationRepository]. Only one stablecoin card can be selected at a time.
 */
@Composable
fun StablecoinListComposable(
    chainID: BigInteger,
    stablecoins: StablecoinInformationRepository,
    selectedStablecoin: MutableState<String?>
) {
    val stablecoinInformationEntries = (stablecoins.stablecoinInformation[chainID] ?: mapOf()).entries

    Column {
        for(stablecoinInfoListEntry in stablecoinInformationEntries) {
            val color = if (selectedStablecoin.value == stablecoinInfoListEntry.key) Color.Green else Color.Black
            Button(
                onClick = {
                    selectedStablecoin.value = stablecoinInfoListEntry.key
                },
                content = {
                    Text(
                        text = stablecoinInfoListEntry.value.name,
                        fontWeight = FontWeight.Bold
                    )
                },
                border = BorderStroke(1.dp, color),
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = Color.Transparent,
                    contentColor = Color.Black
                ),
                modifier = Modifier
                    .width(400.dp)
                    .height(50.dp)
                    .padding(vertical = 5.dp),
                elevation = null
            )
        }
    }
}

/**
 * Displays a [TextField] customized to accept positive stablecoin amounts with up to six decimal places of precision
 */
@Composable
fun StablecoinAmountComposable(
    amountString: MutableState<String>,
    amount: MutableState<BigDecimal>
) {
    TextField(
        value = amountString.value,
        onValueChange = {
            try {
                val newAmount = BigDecimal(it)
                // Don't allow negative values, and limit to 6 decimal places
                if (newAmount >= BigDecimal.ZERO && newAmount.scale() <= 6) {
                    amount.value = newAmount
                    amountString.value = it
                }
            } catch (exception: NumberFormatException) {
                /*
                If the change prevents us from creating a BigDecimal minimum amount value, then we don't allow that
                change
                 */
            }
        },
        textStyle = MaterialTheme.typography.h5,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
    )
}

/**
 * Displays a vertical list of settlement method cards, one for each settlement method that the offer has created. These
 * cards can be tapped to indicate that the user is willing to use them to send/receive payment for the offer being
 * created.
 */
@Composable
fun SettlementMethodSelector(
    settlementMethods: List<SettlementMethod>,
    stablecoinCurrencyCode: String,
    selectedSettlementMethods: SnapshotStateList<SettlementMethod>
) {
    Column {
        for (settlementMethod in settlementMethods) {
            SettlementMethodCardComposable(
                settlementMethod = settlementMethod,
                stablecoinCurrencyCode = stablecoinCurrencyCode,
                selectedSettlementMethods = selectedSettlementMethods
            )
        }
    }
}

@Composable
fun SettlementMethodCardComposable(
    settlementMethod: SettlementMethod,
    stablecoinCurrencyCode: String,
    selectedSettlementMethods: SnapshotStateList<SettlementMethod>,
) {

    val isSelected = remember { mutableStateOf(false) }

    val color = if (isSelected.value) Color.Green else Color.Black

    val isEditingPrice = remember { mutableStateOf(false) }

    val price = remember { mutableStateOf(BigDecimal.ZERO) }

    Button(
        onClick = {
            if (isSelected.value) {
                selectedSettlementMethods.removeIf {
                    it.method == settlementMethod.method && it.currency == settlementMethod.currency
                }
                isSelected.value = false
            } else {
                selectedSettlementMethods.add(settlementMethod)
                isSelected.value = true
            }
        },
        content = {
            if (price.value == BigDecimal.ZERO) {
                settlementMethod.price = ""
            } else {
                settlementMethod.price = price.value.toString()
            }
            Row {
                Column(
                    horizontalAlignment = Alignment.Start
                ) {
                    Text(
                        text = buildCurrencyDescription(settlementMethod),
                        color = color,
                        modifier = Modifier.padding(PaddingValues(top = 10.dp))
                    )
                    Button(
                        onClick = {
                            isEditingPrice.value = !isEditingPrice.value
                        },
                        content = {
                            Text(
                                text = buildCreateOfferPriceDescription(settlementMethod, stablecoinCurrencyCode)
                            )
                        },
                        contentPadding = PaddingValues(vertical = 0.dp, horizontal = 0.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color.Transparent,
                            contentColor = Color.Black
                        ),
                        elevation = null
                    )
                    if (isEditingPrice.value) {
                        TextField(
                            label = { Text("Price (${stablecoinCurrencyCode}/${settlementMethod.currency})") },
                            value = settlementMethod.price,
                            onValueChange = {
                                try {
                                    val newPrice = BigDecimal(it)
                                    // Don't allow negative values, and limit to 6 decimal places
                                    if (newPrice >= BigDecimal.ZERO && newPrice.scale() <= 6) {
                                        price.value = newPrice
                                        settlementMethod.price = it
                                    }
                                } catch (exception: NumberFormatException) {
                                    /*
                                    If the change prevents us from creating a BigDecimal minimum amount value, then we
                                    don't allow that change
                                     */
                                }
                            }
                        )
                    }
                }
                Spacer(
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        border = BorderStroke(1.dp, color),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = Color.Transparent,
            contentColor = Color.Black
        ),
        modifier = Modifier.padding(PaddingValues(bottom = 6.dp)).width(400.dp),
        elevation = null,
    )
}

/**
 * Builds a human readable string describing the price specified for this settlement method, such as
 * "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC", or "Price: Tap to specify" if no
 */
fun buildCreateOfferPriceDescription(
    settlementMethod: SettlementMethod,
    stablecoinCurrencyCode: String,
): String {
    return if (settlementMethod.price == "") {
        "Price: Tap to specify"
    } else {
        "Price: ${settlementMethod.price} + ${settlementMethod.currency}/${stablecoinCurrencyCode}"
    }
}

/**
 * Displays a preview of [CreateOfferComposable]
 */
@Preview(
    showBackground = true,
    heightDp = 1200
)
@Composable
fun PreviewCreateOfferComposable() {
    CreateOfferComposable(
        chainID = BigInteger.ONE
    )
}
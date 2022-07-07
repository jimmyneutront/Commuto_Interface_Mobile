package com.commuto.interfacemobile.android.ui

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CutCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import java.util.*

@Composable
fun OfferComposable() {

    val id = UUID.randomUUID()

    val directionString = "Buy"
    val stablecoin = "STBL"
    val directionJoiner = "with"

    val minimumAmount = "10,000"
    val maximumAmount = "20,000"

    val settlementMethods = listOf(
        SettlementMethod("EUR", "SEPA", "0.94"),
        SettlementMethod("USD", "SWIFT", "1.00"),
        SettlementMethod("BSD", "SANDDOLLAR", "1.00"),
    )

    Column(
        modifier = Modifier
            .verticalScroll(rememberScrollState())
    ) {
        Column(
            modifier = Modifier.padding(9.dp)
        ) {
            Text(
                text = "Direction:",
                style =  MaterialTheme.typography.h6,
            )
            DisclosureComposable(
                header = {
                    Text(
                        text = "$directionString $stablecoin $directionJoiner fiat",
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold
                    )
                },
                content = {
                    // TODO: we should build this string dynamically
                    Text("This is a Buy offer: the maker of this offer wants to buy STBL in exchange for fiat")
                }
            )
            OfferAmountComposable(minimumAmount, maximumAmount)
        }
        Row(
            modifier = Modifier.offset(x = 9.dp)
        ) {
            Column {
                SettlementMethodsListComposable(stablecoin, settlementMethods)
            }
        }
        Column(
            modifier = Modifier.padding(9.dp)
        ) {
            DisclosureComposable(
                header = {
                    Text(
                        text = "Advanced Details",
                        style = MaterialTheme.typography.h5,
                        fontWeight = FontWeight.Bold
                    )
                },
                content = {
                    Text(
                        text = "ID: $id"
                    )
                }
            )
        }
    }
}

@Composable
fun OfferAmountComposable(min: String, max: String) {
    Text(
        text = "Amount:",
        style = MaterialTheme.typography.h6
    )
    if (min == max) {
        Text(
            text = "$min STBL",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
    } else {
        Text(
            text = "Minimum: $min STBL",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "Maximum: $max STBL",
            style =  MaterialTheme.typography.h5,
            fontWeight = FontWeight.Bold
        )
    }
}

data class SettlementMethod(val currency: String, val method: String, val price: String)

@Composable
fun SettlementMethodsListComposable(stablecoin: String, settlementMethods: List<SettlementMethod>) {
    Text(
        text = "Settlement methods:",
        style = MaterialTheme.typography.h6
    )
    LazyRow(
        modifier = Modifier.padding(PaddingValues(vertical = 6.dp))
    ) {
        settlementMethods.forEach {
            item {
                SettlementMethodComposable(stablecoin = stablecoin, settlementMethod = it)
                Spacer(modifier = Modifier.width(9.dp))
            }
        }
    }
}

@Composable
fun SettlementMethodComposable(stablecoin: String, settlementMethod: SettlementMethod) {
    Column(
        modifier = Modifier
            .border(width = 1.dp, color = Color.Black, CutCornerShape(0.dp))
            .padding(9.dp)
    ) {
        Text(
            text = "${settlementMethod.currency} via ${settlementMethod.method}",
            modifier = Modifier.padding(3.dp)
        )
        Text(
            text = "Price: ${settlementMethod.price} ${settlementMethod.currency}/$stablecoin",
            modifier = Modifier.padding(3.dp)
        )
    }
}

@Composable
fun DisclosureComposable(header: @Composable () -> Unit, content: @Composable () -> Unit) {
    var isDisclosureExpanded by remember { mutableStateOf(false) }
    val arrowRotationState by animateFloatAsState(if (isDisclosureExpanded) 180f else 0f)
    Column(
        modifier = Modifier
            .animateContentSize(
                animationSpec = tween(
                    durationMillis = 200,
                    easing = LinearEasing,
                )
            )
            .clickable {
                isDisclosureExpanded = !isDisclosureExpanded
            }
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            header()
            IconButton(
                modifier = Modifier.rotate(arrowRotationState),
                onClick = {
                    isDisclosureExpanded = !isDisclosureExpanded
                }
            ) {
                Icon(
                    imageVector = Icons.Default.KeyboardArrowDown,
                    contentDescription = "Drop Down Arrow"
                )
            }
        }
        if (isDisclosureExpanded) {
            content()
        }
    }
}

/**
 * Displays a preview of [OfferComposable].
 */
@Preview(
    showBackground = true
)
@Composable
fun PreviewOfferComposable() {
    OfferComposable()
}
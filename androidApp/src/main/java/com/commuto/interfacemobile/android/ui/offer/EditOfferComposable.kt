package com.commuto.interfacemobile.android.ui.offer

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.commuto.interfacemobile.android.offer.EditingOfferState
import com.commuto.interfacemobile.android.offer.Offer
import com.commuto.interfacemobile.android.ui.SheetComposable
import com.commuto.interfacemobile.android.ui.settlement.PreviewableSettlementMethodTruthSource
import com.commuto.interfacemobile.android.ui.settlement.UISettlementMethodTruthSource

/**
 * Allows the user to edit one of their [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)s.
 *
 * @param offer The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) for which this view
 * allows editing.
 * @param offerTruthSource The [OffersViewModel] that acts as a single source of truth for all offer-related data.
 * @param settlementMethodTruthSource An object implementing [UISettlementMethodTruthSource] that acts as a single
 * source of truth for all settlement-method-related data.
 * @param stablecoinCurrencyCode The currency code of the offer's stablecoin.
 */
@Composable
fun EditOfferComposable(
    offer: Offer?,
    offerTruthSource: UIOfferTruthSource,
    settlementMethodTruthSource: UISettlementMethodTruthSource,
    stablecoinCurrencyCode: String
) {

    /**
     * Indicates whether we are showing the sheet that allows the user to edit the offer, if they are the maker.
     */
    val isShowingEditOfferSheet = remember { mutableStateOf(false) }

    if (offer == null) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Text(
                text = "This Offer is not available.",
            )
        }
    } else {
        DisposableEffect(LocalLifecycleOwner.current) {
            onDispose {
                // Clear the "Offer Edited" message once the user leaves EditOfferView
                if (offer.editingOfferState.value == EditingOfferState.COMPLETED) {
                    offer.editingOfferState.value = EditingOfferState.NONE
                }
            }
        }
        val editOfferButtonLabel = if (offer.editingOfferState.value == EditingOfferState.NONE ||
            offer.editingOfferState.value == EditingOfferState.EXCEPTION ||
            offer.editingOfferState.value == EditingOfferState.COMPLETED) "Edit Offer" else
            "Editing Offer"
        val editOfferButtonOutlineColor = if (offer.editingOfferState.value == EditingOfferState.VALIDATING ||
            offer.editingOfferState.value == EditingOfferState.SENDING_TRANSACTION ||
            offer.editingOfferState.value == EditingOfferState.AWAITING_TRANSACTION_CONFIRMATION) Color.Black
        else Color.Gray
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
                settlementMethodTruthSource = settlementMethodTruthSource,
                stablecoinCurrencyCode = stablecoinCurrencyCode,
                selectedSettlementMethods = offer.selectedSettlementMethods
            )
            if (offer.editingOfferState.value == EditingOfferState.EXCEPTION) {
                Text(
                    text = offer.editingOfferException?.message ?: "An unknown exception occurred",
                    style =  MaterialTheme.typography.h6,
                    color = Color.Red
                )
            } else if (offer.editingOfferState.value == EditingOfferState.COMPLETED) {
                Text(
                    text = "Offer Edited.",
                    style =  MaterialTheme.typography.h6,
                )
            }
            Button(
                onClick = {
                    // Don't let the user try to edit the offer if it is currently being edited
                    if (offer.editingOfferState.value == EditingOfferState.NONE ||
                        offer.editingOfferState.value == EditingOfferState.EXCEPTION ||
                        offer.editingOfferState.value == EditingOfferState.COMPLETED) {
                        isShowingEditOfferSheet.value = true
                    }
                },
                content = {
                    Text(
                        text = editOfferButtonLabel,
                        style = MaterialTheme.typography.h4,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                },
                border = BorderStroke(3.dp, editOfferButtonOutlineColor),
                colors = ButtonDefaults.buttonColors(
                    backgroundColor =  Color.Transparent,
                    contentColor = Color.Black,
                ),
                elevation = null,
                modifier = Modifier.width(400.dp),
            )
        }

        SheetComposable(
            isPresented = isShowingEditOfferSheet,
            content = { closeSheet ->
                TransactionGasDetailsComposable(
                    closeSheet = closeSheet,
                    title = "Edit Offer",
                    buttonLabel = "Edit Offer",
                    buttonAction = { createdTransaction ->
                        offerTruthSource.editOffer(
                            offer = offer,
                            newSettlementMethods = offer.selectedSettlementMethods,
                            offerEditingTransaction = createdTransaction,
                        )
                    },
                    runOnAppearance = { editingOfferTransaction, transactionCreationException ->
                        if (offer.editingOfferState.value == EditingOfferState.NONE ||
                            offer.editingOfferState.value == EditingOfferState.EXCEPTION) {
                            offerTruthSource.createEditOfferTransaction(
                                offer = offer,
                                newSettlementMethods = offer.selectedSettlementMethods,
                                createdTransactionHandler = { createdTransaction ->
                                    editingOfferTransaction.value = createdTransaction
                                },
                                exceptionHandler = { exception ->
                                    transactionCreationException.value = exception
                                }
                            )
                        }
                    }
                )
            }
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
        offer = Offer.sampleOffers[0],
        offerTruthSource = PreviewableOfferTruthSource(),
        settlementMethodTruthSource = PreviewableSettlementMethodTruthSource(),
        stablecoinCurrencyCode = "STBL"
    )
}

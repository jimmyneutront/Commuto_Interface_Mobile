//
//  EditOfferView.swift
//  iosApp
//
//  Created by jimmyt on 8/6/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import web3swift

/**
 Allows the user to edit one of their [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)s.
 */
struct EditOfferView<Offer_TruthSource, SettlementMethod_TruthSource>: View where Offer_TruthSource: UIOfferTruthSource, SettlementMethod_TruthSource: UISettlementMethodTruthSource {
    
    init(
        offer: Offer,
        offerTruthSource: Offer_TruthSource,
        settlementMethodTruthSource: SettlementMethod_TruthSource,
        stablecoinCurrencyCode: String
    ) {
        self.stablecoinCurrencyCode = stablecoinCurrencyCode
        self.offer = offer
        self.offerTruthSource = offerTruthSource
        self.settlementMethodTruthSource = settlementMethodTruthSource
    }
    
    /**
     The currency code of the offer's stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    /**
     An `Array` of `SettlementMethod`s from which the user can choose.
     */
    private var settlementMethods: [SettlementMethod] = SettlementMethod.sampleSettlementMethodsEmptyPrices
    
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) for which this view allows editing.
     */
    @ObservedObject var offer: Offer
    
    /**
     An object adopting the `OfferTruthSource` protocol that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: Offer_TruthSource
    
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodTruthSource: SettlementMethod_TruthSource
    
    /**
     Indicates whether we are showing the sheet that allows the user to cancel the offer, if they are the maker.
     */
    @State private var isShowingEditOfferSheet = false
    
    /**
     The string that will be displayed in the label of the button that edits the offer.
     */
    var editOfferButtonLabel: String {
        if offer.editingOfferState == .none ||
            offer.editingOfferState == .error ||
            offer.editingOfferState == .completed {
            return "Edit Offer"
        } else {
            return "Editing Offer"
        }
    }
    
    /**
     The color of the rounded rectangle stroke surrounding the button that edits the offer.
     */
    var editOfferButtonOutlineColor: Color {
        if offer.editingOfferState == .validating ||
            offer.editingOfferState == .sendingTransaction ||
            offer.editingOfferState == .awaitingTransactionConfirmation {
            return Color.gray
        } else {
            return Color.primary
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                HStack {
                    Text("Settlement methods:")
                        .font(.title2)
                    Spacer()
                }
                SettlementMethodSelector(
                    settlementMethodViewModel: settlementMethodTruthSource,
                    stablecoinCurrencyCode: stablecoinCurrencyCode,
                    selectedSettlementMethods: $offer.selectedSettlementMethods
                )
                if offer.editingOfferState == .error {
                    HStack {
                        Text(offer.editingOfferError?.localizedDescription ?? "An unknown error occured")
                            .foregroundColor(Color.red)
                        Spacer()
                    }
                } else if offer.editingOfferState == .completed {
                    HStack {
                        Text("Offer Edited.")
                        Spacer()
                    }
                }
                Button(
                    action: {
                        // Don't let the user try to edit the offer if it is currently being edited
                        if offer.editingOfferState == .none ||
                            offer.editingOfferState == .error ||
                            offer.editingOfferState == .completed {
                            isShowingEditOfferSheet = true
                        }
                    },
                    label: {
                        Text(editOfferButtonLabel)
                            .font(.largeTitle)
                            .bold()
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(editOfferButtonOutlineColor, lineWidth: 3)
                            )
                    }
                )
                .accentColor(Color.primary)
                .sheet(isPresented: $isShowingEditOfferSheet) {
                    TransactionGasDetailsView(
                        isShowingSheet: $isShowingEditOfferSheet,
                        title: "Edit Offer",
                        buttonLabel: "Edit Offer",
                        buttonAction: { createdTransaction in
                            offerTruthSource.editOffer(
                                offer: offer,
                                newSettlementMethods: offer.selectedSettlementMethods,
                                offerEditingTransaction: createdTransaction
                            )
                        },
                        runOnAppearance: { editingOfferTransactionBinding, transactionCreationErrorBinding in
                            if offer.editingOfferState == .none || offer.editingOfferState == .error {
                                offerTruthSource.createEditOfferTransaction(
                                    offer: offer,
                                    newSettlementMethods: offer.selectedSettlementMethods,
                                    createdTransactionHandler: { createdTransaction in
                                        editingOfferTransactionBinding.wrappedValue = createdTransaction
                                    },
                                    errorHandler: { error in
                                        transactionCreationErrorBinding.wrappedValue = error
                                    }
                                )
                            }
                        }
                    )
                }
            }
            .padding([.leading, .trailing])
        }
        .onDisappear {
            // Clear the "Offer Edited" message once the user leaves EditOfferView
            if offer.editingOfferState == .completed {
                offer.editingOfferState = .none
            }
        }
        .navigationTitle("Edit Offer")
    }
}

/**
 Displays a preview of `EditOfferView` with the stablecoin currency code "STBL".
 */
struct EditOfferView_Previews: PreviewProvider {
    static var previews: some View {
        EditOfferView(
            offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!,
            offerTruthSource: PreviewableOfferTruthSource(),
            settlementMethodTruthSource: PreviewableSettlementMethodTruthSource(),
            stablecoinCurrencyCode: "STBL"
        )
    }
}

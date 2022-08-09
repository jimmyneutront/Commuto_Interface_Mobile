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
struct EditOfferView<TruthSource>: View where TruthSource: UIOfferTruthSource {
    
    init(offer: Offer, offerTruthSource: TruthSource, stablecoinCurrencyCode: String) {
        self.stablecoinCurrencyCode = stablecoinCurrencyCode
        self.offer = offer
        self.offerTruthSource = offerTruthSource
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
    
    /// The `OffersViewModel` that acts as a single source of truth for all offer-related data.
    @ObservedObject var offerTruthSource: TruthSource
    
    /**
     The string that will be displayed in the label of the button that edits the offer.
     */
    var editOfferButtonLabel: String {
        if offer.editingOfferState != .editing {
            return "Edit Offer"
        } else {
            return "Editing Offer"
        }
    }
    
    /**
     The color of the rounded rectangle stroke surrounding the button that edits the offer.
     */
    var editOfferButtonOutlineColor: Color {
        if offer.editingOfferState == .editing {
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
                    settlementMethods: settlementMethods,
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
                        if offer.editingOfferState != .editing {
                            offerTruthSource.editOffer(
                                offer: offer,
                                newSettlementMethods: offer.selectedSettlementMethods
                            )
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
            stablecoinCurrencyCode: "STBL"
        )
    }
}

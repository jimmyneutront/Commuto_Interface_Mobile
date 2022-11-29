//
//  CancelOfferView.swift
//  iosApp
//
//  Created by jimmyt on 11/25/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import web3swift

/**
 Allows the user to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) that they have made, and displays the neccessary gas and gas cost before actually cancelling the Offer. This should only be presented inside a sheet.
 */
struct CancelOfferView<Offer_TruthSource>: View where Offer_TruthSource: UIOfferTruthSource {
    
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) that this `CancelOfferView` allows the user to cancel.
     */
    @ObservedObject var offer: Offer
    
    /**
     A binding that controls whether or not the sheet containing this `View` is presented.
     */
    @Binding var isShowingCancelOfferSheet: Bool
    
    /**
     The `OffersViewModel` that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: Offer_TruthSource
    
    /**
     The created `EthereumTransaction` that will cancel the offer, or `nil` if no such transaction is available.
     */
    @State var cancelOfferTransaction: EthereumTransaction? = nil
    
    /**
     The `Error` that has occured while creating the transaction for offer cancellation, or `nil` if no such error has occured.
     */
    @State var transactionCreationError: Error? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading) {
                HStack() {
                    Text("Cancel Offer")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Button(
                        action: {
                            isShowingCancelOfferSheet = false
                        },
                        label: {
                            Text("Close")
                        }
                    )
                    .accentColor(Color.primary)
                }
                if let transaction = cancelOfferTransaction {
                    if let gasLimit = transaction.parameters.gasLimit, let maxFeePerGas = transaction.parameters.maxFeePerGas {
                        Text("Estimated Gas:")
                            .font(.title2)
                        Text(String(gasLimit))
                            .font(.title)
                            .bold()
                        Text("Max Fee Per Gas (Wei):")
                            .font(.title2)
                        Text(String(maxFeePerGas))
                            .font(.title)
                            .bold()
                        Text("Estimated Total Cost (Wei):")
                            .font(.title2)
                        Text(String(gasLimit * maxFeePerGas))
                            .font(.title)
                            .bold()
                        if let transactionCreationError = transactionCreationError {
                            Text(transactionCreationError.localizedDescription)
                                .foregroundColor(Color.red)
                        }
                        Button(
                            action: {
                                // Close the sheet in which this view is presented as soon as the user begins the canceling process.
                                offerTruthSource.cancelOffer(offer: offer, offerCancellationTransaction: cancelOfferTransaction)
                                isShowingCancelOfferSheet = false
                            },
                            label: {
                                Text("Cancel Offer")
                                    .font(.largeTitle)
                                    .bold()
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary, lineWidth: 3)
                                    )
                            }
                        )
                        .accentColor(Color.primary)
                    } else {
                        Text("Unable to estimate gas and gas fee.")
                        if let transactionCreationError = transactionCreationError {
                            Text(transactionCreationError.localizedDescription)
                                .foregroundColor(Color.red)
                        }
                    }
                } else if let transactionCreationError = transactionCreationError {
                    Text(transactionCreationError.localizedDescription)
                        .foregroundColor(Color.red)
                } else {
                    Text("Creating transaction...")
                }
            }
            .padding()
            .onAppear {
                if offer.cancelingOfferState == .none || offer.cancelingOfferState == .error {
                    offerTruthSource.createCancelOfferTransaction(
                        offer: offer,
                        createdTransactionHandler: { createdTransaction in
                            cancelOfferTransaction = createdTransaction
                        },
                        errorHandler: { error in
                            transactionCreationError = error
                        }
                    )
                }
            }
        }
    }
}

/**
 Displays a preview of `CancelOfferView`.
 */
struct CancelOfferView_Previews: PreviewProvider {
    @State static var isShowingCancelOfferSheet = true
    static var previews: some View {
        CancelOfferView(
            offer: Offer.sampleOffers[Offer.sampleOfferIds[2]]!,
            isShowingCancelOfferSheet: $isShowingCancelOfferSheet,
            offerTruthSource: PreviewableOfferTruthSource()
        )
    }
}

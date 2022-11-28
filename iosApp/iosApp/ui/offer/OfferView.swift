//
//  OfferView.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI
import BigInt

/**
 Displays information about a specific [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct OfferView<Offer_TruthSource, SettlementMethod_TruthSource>: View where Offer_TruthSource: UIOfferTruthSource, SettlementMethod_TruthSource: UISettlementMethodTruthSource {
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information. Defaults to `StablecoinInformationRepository.hardhatStablecoinInfoRepo` if no other value is provided.
     */
    let stablecoinInfoRepo = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    /**
     Controls whether the `DisclosureGroup` displaying a description of the offer direction is open.
     */
    @State private var isDirectionDescriptionExpanded = false
    /**
     Controls whether the `DisclosureGroup` displaying advanced details about the offer is open.
     */
    @State private var isAdvancedDetailsDescriptionExpanded = false
    /**
     Controls whether the `DisclosureGroup` displaying service fee rate details is open.
     */
    @State private var isServiceFeeRateDescriptionExpanded = false
    
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) about which this `OfferView` displays information.
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
     The string that will be displayed in the label of the button that cancels the offer.
     */
    var cancelingOfferButtonLabel: String {
        if offer.cancelingOfferState == .none || offer.cancelingOfferState == .error {
            return "Cancel Offer"
        } else if offer.cancelingOfferState == .canceling {
            return "Canceling Offer"
        } else {
            return "Offer Canceled"
        }
    }
    
    /**
     The color of the outline around the button that cancels the offer.
     */
    var cancelingOfferButtonOutlineColor: Color {
        if offer.cancelingOfferState == .none || offer.cancelingOfferState == .error {
            return Color.red
        } else {
            return Color.gray
        }
    }
    
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
    
    @State private var isShowingTakeOfferSheet = false
    
    /**
     Indicates whether or not we are showing the sheet that allows the user to cancel the offer, if they are the maker.
     */
    @State private var isShowingCancelOfferSheet = false
    
    /**
     The string that  will be displayed in the label  of the button that edits the offer.
     */
    var takeOfferButtonLabel: String {
        if offer.takingOfferState == .none || offer.takingOfferState == .error {
            return "Take Offer"
        } else if offer.takingOfferState == .completed {
            return "Offer Taken"
        } else {
            return "Taking Offer"
        }
    }
    
    var body: some View {
        if (!offer.isCreated && offer.cancelingOfferState == .none) {
            // If isCreated is false and cancelingOfferState is .none, then the offer has been canceled by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS canceled by the user of this interface, we do show offer info, but relabel the "Cancel Offer" button to indicate that the offer has been canceled.
            Text("This Offer has been canceled.")
        } else if (offer.isTaken && offer.takingOfferState == .none) {
            // If isTaken is true and takingOfferState is .none, then the offer has been taken by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS taken by the user of this interface, we do show offer info, but relabel the "Take Offer" button to indicate that the offer has been taken.
            Text("This Offer has been taken.")
        } else {
            let stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(chainID: offer.chainID, contractAddress: offer.stablecoin)
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Direction:")
                                .font(.title2)
                            Spacer()
                        }
                        .offset(x: 0.0, y: 10.0)
                        DisclosureGroup(
                            isExpanded: $isDirectionDescriptionExpanded,
                            content: {
                                HStack {
                                    Text(buildDirectionDescriptionString(stablecoinInformation: stablecoinInformation))
                                        .padding(.bottom, 1)
                                    Spacer()
                                }
                            },
                            label: {
                                Text(buildDirectionString(stablecoinInformation: stablecoinInformation))
                                    .font(.title2)
                                    .bold()
                                    .multilineTextAlignment(.leading)
                            }
                        )
                        .accentColor(Color.primary)
                        if !offer.isUserMaker {
                            Text("If you take this offer, you will:")
                                .font(.title2)
                            Text(createRoleDescription(offerDirection: offer.direction, stablecoinInformation: stablecoinInformation))
                                .font(.title)
                                .bold()
                        }
                        OfferAmountView(stablecoinInformation: stablecoinInformation, minimum: offer.amountLowerBound, maximum: offer.amountUpperBound, securityDeposit: offer.securityDepositAmount)
                        HStack {
                            Text("Settlement methods:")
                                .font(.title2)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    .padding([.leading, .trailing, .top])
                    SettlementMethodListView(
                        stablecoinInformation: stablecoinInformation,
                        settlementMethods: offer.settlementMethods,
                        isUserMaker: offer.isUserMaker
                    )
                        .padding(.leading)
                    VStack(alignment: .leading) {
                        DisclosureGroup(
                            isExpanded: $isServiceFeeRateDescriptionExpanded,
                            content: {
                                HStack {
                                    Text("To take this offer, you must pay a fee equal to " + String(Double(offer.serviceFeeRate) / 100.0) + " percent of the amount to be exchanged.")
                                    Spacer()
                                }
                            },
                            label: {
                                Text("Service Fee Rate: " + String(Double(offer.serviceFeeRate) / 100.0) + "%")
                                    .font(.title2)
                                    .bold()
                            }
                        )
                        .accentColor(Color.primary)
                        ServiceFeeAmountView(
                            stablecoinInformation: stablecoinInformation,
                            minimumString: String(offer.serviceFeeRate * offer.amountLowerBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000))),
                            maximumString: String(offer.serviceFeeRate * offer.amountUpperBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000)))
                        )
                        DisclosureGroup(
                            isExpanded: $isAdvancedDetailsDescriptionExpanded,
                            content: {
                                // Note that the empty string should never be displayed, since a "not available" message is displayed if offer is nil.
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("Offer ID: " + offer.id.uuidString)
                                            .padding(.bottom, 1)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("Chain ID: " + String(offer.chainID))
                                        Spacer()
                                    }
                                }
                            },
                            label: {
                                Text("Advanced Details")
                                    .font(.title2)
                                    .bold()
                            }
                        )
                        .accentColor(Color.primary)
                        if (offer.isUserMaker) {
                            // The user is the maker of this offer, so we display buttons for editing and canceling the offer
                            if offer.editingOfferState == .error {
                                Text("Error Editing Offer: " + (offer.editingOfferError?.localizedDescription ?? "An unknown error occured"))
                                    .foregroundColor(Color.red)
                            }
                            NavigationLink(destination:
                                            EditOfferView(
                                                offer: offer,
                                                offerTruthSource: offerTruthSource,
                                                settlementMethodTruthSource: settlementMethodTruthSource,
                                                stablecoinCurrencyCode: stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
                                            )
                            ) {
                                Text(editOfferButtonLabel)
                                    .font(.largeTitle)
                                    .bold()
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary, lineWidth: 3)
                                    )
                            }
                            .accentColor(Color.primary)
                            if offer.cancelingOfferState == .error {
                                HStack {
                                    Text(offer.cancelingOfferError?.localizedDescription ?? "An unknown error occurred")
                                        .foregroundColor(Color.red)
                                    Spacer()
                                }
                            }
                            Button(
                                action: {
                                    // Don't let the user try to cancel the offer if it is already canceled or being canceled
                                    if offer.cancelingOfferState == .none || offer.cancelingOfferState == .error {
                                        isShowingCancelOfferSheet = true
                                    }
                                },
                                label: {
                                    Text(cancelingOfferButtonLabel)
                                        .font(.largeTitle)
                                        .bold()
                                        .padding(10)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(cancelingOfferButtonOutlineColor, lineWidth: 3)
                                        )
                                }
                            )
                            .accentColor(Color.red)
                            .sheet(isPresented: $isShowingCancelOfferSheet) {
                                CancelOfferView(
                                    offer: offer,
                                    isShowingCancelOfferSheet: $isShowingCancelOfferSheet,
                                    offerTruthSource: offerTruthSource
                                )
                            }
                        } else if (offer.state == .offerOpened) {
                            // The user is not the maker of this offer, so we display a button for canceling the offer
                            if offer.takingOfferState == .error {
                                Text(offer.takingOfferError?.localizedDescription ?? "An unknown error occured")
                                    .foregroundColor(Color.red)
                            }
                            // We should only display the "Take Offer" button if the user is NOT the maker and if the offer is in the offerOpened state
                            Button(
                                action: {
                                    isShowingTakeOfferSheet = true
                                },
                                label: {
                                    Text(takeOfferButtonLabel)
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
                            .sheet(isPresented: $isShowingTakeOfferSheet) {
                                TakeOfferView(
                                    offerID: offer.id,
                                    offerTruthSource: offerTruthSource,
                                    settlementMethodTruthSource: settlementMethodTruthSource
                                )
                            }
                        }
                    }
                    .offset(x: 0.0, y: -10.0)
                    .padding()
                    Spacer()
                }
                .offset(x:0.0, y: -30.0)
            }
            .navigationBarTitle(Text("Offer"))
        }
    }
    
    /**
     Creates the text for the label of the direction `DisclosureGroup`.
     
     - Parameter stablecoinInformation: An optional `StablecoinInformation` for this offer's stablecoin.
     */
    func buildDirectionString(stablecoinInformation: StablecoinInformation?) -> String {
        let stablecoinCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        var directionJoiner: String {
            switch offer.direction {
            case .buy:
                return "with"
            case .sell:
                return "for"
            }
        }
        return offer.direction.string + " " + stablecoinCode + " " + directionJoiner + " fiat"
    }
    
    /**
     Creates the text for the direction description within the direction `DisclosureGroup`.
     
     - Parameter stablecoinInformation: An optional `StablecoinInformation` for this offer's stablecoin.
     */
    func buildDirectionDescriptionString(stablecoinInformation: StablecoinInformation?) -> String {
        let stablecoinName = stablecoinInformation?.name ?? "Unknown Stablecoin"
        // We should never get the empty string here because no offer information will be displayed if offer is nil
        return "This is a " + offer.direction.string + " offer: The maker of this offer wants to " + offer.direction.string.lowercased() + " " + stablecoinName + " in exchange for fiat."
    }
    
    /**
     Creates a role discription string (such as "Buy USDC" or "Sell DAI" for the user, based on the direction of the offer. This should only be displayed if the user is not the maker of the offer.
     
     - Parameters:
        - offerDescription: The `direction` property of the `Offer`.
        - stablecoinInformation: An optional `StablecoinInformation` for this offer's stablecoin. If this is `nil`, this uses the symbol "Unknown Stablecoin".
     
     - Returns: A role description.
     */
    func createRoleDescription(offerDirection: OfferDirection, stablecoinInformation: StablecoinInformation?) -> String {
        var direction: String {
            switch offerDirection {
            case .buy:
                // The maker is offering to buy stablecoin, so if the user of this interface takes the offer, they must sell stablecoin
                return "Sell"
            case .sell:
                // The maker is offering to sell stablecoin, so if the user of this interface takes the offer, they must buy stablecoin
                return "Buy"
            }
        }
        return "\(direction) \(stablecoinInformation?.currencyCode ?? "Unknown Stablecoin")"
    }
    
}

/**
 Displays a horizontally scrolling list of `SettlementMethodView`s.
 */
struct SettlementMethodListView: View {
    /**
     The `StablecoinInformation` struct for the offer's stablecoin, or `nil` if such a struct cannot be resolved from the offer's chain ID and stablecoin address.
     */
    let stablecoinInformation: StablecoinInformation?
    /**
     The settlement methods to be displayed.
     */
    let settlementMethods: [SettlementMethod]
    /**
     Indicates whether the user is the maker of the offer for which this is displaying settlement methods.
     */
    let isUserMaker: Bool
    
    var body: some View {
        let stablecoinCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        
        if settlementMethods.count > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(settlementMethods) { settlementMethod in
                        SettlementMethodView(stablecoin: stablecoinCode, settlementMethod: settlementMethod, isUserMaker: isUserMaker)
                    }
                    .padding(5)
                }
            }
        } else {
            HStack {
                Text("No Settlement Methods Found")
                Spacer()
            }
        }
    }
}

/**
 Displays a card containing information about a settlement method.
 */
struct SettlementMethodView: View {
    /**
     The human readable symbol of the stablecoin for which the offer related to this settlement method has been made.
     */
    let stablecoin: String
    /**
     The `SettlementMethod` that this card displays.
     */
    let settlementMethod: SettlementMethod
    /**
     Indicates whether the user of this interface is the maker of the offer for which this is displaying settlement method information.
     */
    let isUserMaker: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(buildCurrencyDescription())
                .padding(1)
            Text(buildPriceDescription())
                .padding(1)
            if isUserMaker {
                SettlementMethodPrivateDetailView(settlementMethod: settlementMethod)
            }
        }
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary, lineWidth: 3)
        )
    }
    
    /**
     Builds a human readable string describing the currency and transfer method, such as "EUR via SEPA" or "USD via SWIFT"
     */
    func buildCurrencyDescription() -> String {
        return settlementMethod.currency + " via " + settlementMethod.method
    }
    
    /**
     Builds a human readable string describing the price specified for this settlement method, such as "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC"
     */
    func buildPriceDescription() -> String {
        return "Price: " + settlementMethod.price + " " + settlementMethod.currency + "/" + stablecoin
    }
    
}

/**
 Displays previews of `OfferView` in light and dark mode, in German.
 */
struct OfferView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OfferView(
                offer: Offer.sampleOffers[Offer.sampleOfferIds[2]]!,
                offerTruthSource: PreviewableOfferTruthSource(),
                settlementMethodTruthSource: PreviewableSettlementMethodTruthSource()
            )
            OfferView(
                offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!,
                offerTruthSource: PreviewableOfferTruthSource(),
                settlementMethodTruthSource: PreviewableSettlementMethodTruthSource()
            ).preferredColorScheme(.dark)
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}

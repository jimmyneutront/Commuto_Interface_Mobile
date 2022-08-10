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
struct OfferView<TruthSource>: View where TruthSource: UIOfferTruthSource {
    
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
    
    /// The `OffersViewModel` that acts as a single source of truth for all offer-related data.
    @ObservedObject var offerTruthSource: TruthSource
    
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
    
    var body: some View {
        let stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(chainID: offer.chainID, contractAddress: offer.stablecoin)
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                VStack {
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
                                .font(.title)
                                .bold()
                                .multilineTextAlignment(.leading)
                        }
                    )
                    .accentColor(Color.primary)
                    OfferAmountView(stablecoinInformation: stablecoinInformation, minimum: offer.amountLowerBound, maximum: offer.amountUpperBound, securityDeposit: offer.securityDepositAmount)
                    HStack {
                        Text("Settlement methods:")
                            .font(.title2)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding([.leading, .trailing, .top])
                SettlementMethodListView(stablecoinInformation: stablecoinInformation, settlementMethods: offer.settlementMethods)
                    .padding(.leading)
                VStack {
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
                        if offer.editingOfferError != nil {
                            HStack {
                                Text("Error Editing Offer: " + (offer.editingOfferError?.localizedDescription ?? "An unknown error occured"))
                                    .foregroundColor(Color.red)
                                Spacer()
                            }
                        }
                        NavigationLink(destination:
                                        EditOfferView(
                                            offer: offer,
                                            offerTruthSource: offerTruthSource,
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
                        Button (
                            action: {
                                // Don't let the user try to cancel the offer if it is already canceled or being canceled
                                if offer.cancelingOfferState == .none || offer.cancelingOfferState == .error {
                                    offerTruthSource.cancelOffer(offer)
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
}

/**
 A view that displays the minimum and maximum amount stablecoin that the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)  is willing to exchange.
 */
struct OfferAmountView: View {
    /**
     The `StablecoinInformation` struct for the offer's stablecoin, or `nil` if such a struct cannot be resolved from the offer's chain ID and stablecoin address.
     */
    let stablecoinInformation: StablecoinInformation?
    
    /**
     The offer's `amountLowerBound` divided by ten raised to the power of the stablecoin's decimal count, as a string.
     */
    let minimumString: String
    /**
     The offer's `amountUpperBound` divided by ten raised to the power of the stablecoin's decimal count, as a string.
     */
    let maximumString: String
    /**
     The offer's `securityDepositAmount` divided by ten raised to the  power of the stablecoin's decimal count, as a string.
     */
    let securityDepositString: String
    
    init(stablecoinInformation: StablecoinInformation?, minimum: BigUInt, maximum: BigUInt, securityDeposit: BigUInt) {
        self.stablecoinInformation = stablecoinInformation
        let stablecoinDecimal = stablecoinInformation?.decimal ?? 1
        minimumString = String(minimum / BigUInt(10).power(stablecoinDecimal))
        maximumString = String(maximum / BigUInt(10).power(stablecoinDecimal))
        securityDepositString = String(securityDeposit / BigUInt(10).power(stablecoinDecimal))
    }
    
    var body: some View {
        let currencyCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        HStack {
            let headerString = (stablecoinInformation != nil) ? "Amount: " : "Amount (in token base units):"
            Text(headerString)
                .font(.title2)
            Spacer()
        }
        .padding(.bottom, 2)
        if minimumString == maximumString {
            HStack {
                Text(minimumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
            }
        } else {
            HStack {
                Text("Minimum: " + minimumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
                
            }
            HStack {
                Text("Maximum: " + maximumString + " " + currencyCode)
                    .font(.title2).bold()
                Spacer()
            }
        }
        HStack {
            Text("Security Deposit: " + securityDepositString + " " + currencyCode)
                .font(.title3)
            Spacer()
        }
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
    
    var body: some View {
        let stablecoinCode = stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
        
        if settlementMethods.count > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(settlementMethods) { settlementMethod in
                        SettlementMethodView(stablecoin: stablecoinCode, settlementMethod: settlementMethod)
                    }
                    .padding(5)
                }
            }
        } else {
            HStack {
                Text("No settlement methods found")
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
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(buildCurrencyDescription())
                .padding(1)
            Text(buildPriceDescription())
                .padding(1)
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
                offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!,
                offerTruthSource: PreviewableOfferTruthSource()
            )
            OfferView(
                offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!,
                offerTruthSource: PreviewableOfferTruthSource()
            ).preferredColorScheme(.dark)
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}

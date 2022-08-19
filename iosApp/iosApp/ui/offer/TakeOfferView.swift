//
//  TakeOfferView.swift
//  iosApp
//
//  Created by jimmyt on 8/10/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import SwiftUI

/**
 Allows the user to specify a stablecoin amount, select a settlement method and take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct TakeOfferView<TruthSource>: View where TruthSource: UIOfferTruthSource {
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information.
     */
    let stablecoinInfoRepo = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    /**
     The ID of the [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) about which this `TakeOfferView` displays information.
     */
    let offerID: UUID
    
    /**
     The `OffersViewModel` that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: TruthSource
    
    /**
     A `NumberFormatter` for formatting stablecoin amounts.
     */
    let stablecoinFormatter = NumberFormatter()
    
    /**
     The amount of stablecoin that the user has indicated they want to buy/sell. If the minimum and maximum amount of the offer this `View` represents are equal, this will not be used.
     */
    @State var specifiedStablecoinAmount = 0
    
    /**
     The settlement method by which the user has chosen to send/receive traditional currency payment, or `nil` if the user has not made such a selection.
     */
    @State var selectedSettlementMethod: SettlementMethod? = nil
    
    /**
     Creates the string that will be displayed in the label  of the button that edits the offer.
     */
    func createTakeOfferButtonLabel(offer: Offer) -> String {
        if offer.takingOfferState == .none || offer.takingOfferState == .error {
            return "Take Offer"
        } else if offer.takingOfferState == .completed {
            return "Offer Taken"
        } else {
            return "Taking Offer"
        }
    }
    
    /**
     Gets the color of the outline around the button that cancels the offer.
     */
    func getTakeOfferButtonOutlineColor(offer: Offer) -> Color {
        if offer.takingOfferState == .none || offer.takingOfferState == .error {
            return Color.primary
        } else {
            return Color.gray
        }
    }
    
    var body: some View {
        if let offer = offerTruthSource.offers[offerID] {
            if (!offer.isCreated && offer.cancelingOfferState == .none) {
                // If isCreated is false and cancelingOfferState is .none, then the offer has been canceled by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS canceled by the user of this interface, we do show offer info, but relabel the "Cancel Offer" button to indicate that the offer has been canceled.
                Text("This Offer has been canceled.")
            } else if (offer.isTaken && offer.takingOfferState == .none) {
                // If isTaken is true and takingOfferState is .none, then the offer has been taken by someone OTHER than the user of this interface, and therefore we don't show any offer info, just this message. Otherwise, if this offer WAS taken by the user of this interface, we do show offer info, but relabel the "Take Offer" button to indicate that the offer has been taken.
                Text("This Offer has been taken.")
            } else {
                let stablecoinInformation = stablecoinInfoRepo.getStablecoinInformation(
                    chainID: offer.chainID,
                    contractAddress: offer.stablecoin
                )
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading) {
                        Text("Take \(offer.direction.string) Offer")
                            .font(.title)
                            .bold()
                        OfferAmountView(
                            stablecoinInformation: stablecoinInformation,
                            minimum: offer.amountLowerBound,
                            maximum: offer.amountUpperBound,
                            securityDeposit: offer.securityDepositAmount
                        )
                        if (offer.amountLowerBound != offer.amountUpperBound) {
                            Text("Enter an Amount:")
                            StablecoinAmountField(value: $specifiedStablecoinAmount, formatter: stablecoinFormatter)
                            ServiceFeeAmountView(
                                stablecoinInformation: stablecoinInformation,
                                amount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                serviceFeeRate: offer.serviceFeeRate
                            )
                        } else {
                            ServiceFeeAmountView(
                                stablecoinInformation: stablecoinInformation,
                                minimumString: String(offer.serviceFeeRate * offer.amountLowerBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000))),
                                maximumString: String(offer.serviceFeeRate * offer.amountUpperBound / (BigUInt(10).power(stablecoinInformation?.decimal ?? 1) * BigUInt(10000)))
                            )
                        }
                        Text(createSettlementMethodHeader(numberOfSettlementMethods: offer.settlementMethods.count))
                            .font(.title2)
                        ImmutableSettlementMethodSelector(
                            settlementMethods: offer.settlementMethods,
                            selectedSettlementMethod: $selectedSettlementMethod,
                            stablecoinCurrencyCode: stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
                        )
                        if (offer.takingOfferState != .none && offer.takingOfferState != .error) {
                            Text(offer.takingOfferState.description)
                                .font(.title2)
                        }
                        if offer.takingOfferState == .error {
                            Text(offer.takingOfferError?.localizedDescription ?? "An unknown error occured")
                                .foregroundColor(Color.red)
                        }
                        Button(
                            action: {
                                if offer.takingOfferState == .none || offer.takingOfferState == .error {
                                    offerTruthSource.takeOffer(
                                        offer: offer,
                                        takenSwapAmount: NSNumber(floatLiteral: Double(specifiedStablecoinAmount)).decimalValue,
                                        settlementMethod: selectedSettlementMethod
                                    )
                                }
                            },
                            label: {
                                Text(createTakeOfferButtonLabel(offer: offer))
                                    .font(.largeTitle)
                                    .bold()
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(getTakeOfferButtonOutlineColor(offer: offer), lineWidth: 3)
                                    )
                            }
                        )
                        .accentColor(Color.primary)
                    }
                    .padding()
                }
                .onAppear {
                    // Set up the stablecoin NumberFormatter when this view appears
                    stablecoinFormatter.numberStyle = .currency
                    stablecoinFormatter.maximumFractionDigits = 3
                }
            }
        } else {
            Text("This Offer is not available.")
        }
    }
    
    func createSettlementMethodHeader(numberOfSettlementMethods: Int) -> String {
        if numberOfSettlementMethods == 1 {
            return "Settlement Method:"
        } else {
            return "Settlement Methods:"
        }
    }
    
}

/**
 Displays a vertical list of `ImmutableSettlementMethodCard`s, one for each of this offer's settlement methods. Only one `ImmutableSettlementMethodCard` can be selected at a time. When such a card is selected, `selectedSettlementMethod` is set equal to the `SettlementMethod` that card represents.
 */
struct ImmutableSettlementMethodSelector: View {
    
    /**
     The `Offer`'s `SettlementMethod`s.
     */
    let settlementMethods: [SettlementMethod]
    
    /**
     The currently selected `SettlementMethod`, or `nil` if no `SettlementMethod` is currently selected.
     */
    @Binding var selectedSettlementMethod: SettlementMethod?
    
    /**
     The currency code of the Offer's stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        if settlementMethods.count > 0 {
            ForEach(settlementMethods) { settlementMethod in
                
                // If the settlement method that this card represents is the selected settlement method, this card should be colored green.
                let color: Color = {
                    if selectedSettlementMethod?.currency == settlementMethod.currency && selectedSettlementMethod?.price == settlementMethod.price && selectedSettlementMethod?.method == settlementMethod.method {
                        return Color.green
                    } else {
                        return Color.primary
                    }
                }()
                
                Button(action: { selectedSettlementMethod = settlementMethod }) {
                    ImmutableSettlementMethodCard(
                        settlementMethod: settlementMethod,
                        color: color,
                        stablecoinCurrencyCode: stablecoinCurrencyCode
                    )
                }
                .accentColor(color)
            }
        } else {
            Text("No Settlement Methods Found")
        }
    }
}

/**
 Displays a card containing settlement method information that cannot be edited.
 */
struct ImmutableSettlementMethodCard: View {
    
    /**
     The `SettlementMethod` that this card represents.
     */
    var settlementMethod: SettlementMethod
    
    /**
     The color of the stroke surrounding this card and the text within it.
     */
    var color: Color
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(buildCurrencyDescription())
                    .foregroundColor(color)
                    .bold()
                    .padding(1)
                Text(buildPriceDescription())
                    .foregroundColor(color)
                    .bold()
                    .padding(1)
            }
            Spacer()
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 1)
        )
    }
    
    /**
     Builds a human readable string describing the currency and transfer method, such as "EUR via SEPA" or "USD via SWIFT".
     */
    func buildCurrencyDescription() -> String {
        return settlementMethod.currency + " via " + settlementMethod.method
    }
    
    /**
     Builds a human readable string describing the price specified for this settlement method, such as "Price: 0.94 EUR/DAI" or "Price: 1.00 USD/USDC", or "Price: Tap to specify" of this settlement method's price is empty.
     */
    func buildPriceDescription() -> String {
        if settlementMethod.price == "" {
            return "Price: Tap to specify"
        } else {
            return "Price: " + settlementMethod.price + " " + settlementMethod.currency + "/" + stablecoinCurrencyCode
        }
    }
    
}

/**
 Displays a preview of `TakeOfferView`
 */
struct TakeOfferView_Previews: PreviewProvider {
    static var previews: some View {
        TakeOfferView(
            offerID: Offer.sampleOfferIds[2],
            offerTruthSource: PreviewableOfferTruthSource()
        )
    }
}

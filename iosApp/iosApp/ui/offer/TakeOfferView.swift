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
    
    @State var selectedSettlementMethod: SettlementMethod? = nil
    
    var body: some View {
        if let offer = offerTruthSource.offers[offerID] {
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
                    if(offer.settlementMethods.count == 1) {
                        Text("Settlement Method")
                            .font(.title2)
                    } else {
                        Text("Settlement Methods")
                            .font(.title2)
                    }
                    ImmutableSettlementMethodSelector(
                        settlementmethods: offer.settlementMethods,
                        selectedSettlementMethod: $selectedSettlementMethod,
                        stablecoinCurrencyCode: stablecoinInformation?.currencyCode ?? "Unknown Stablecoin"
                    )
                    Spacer()
                    Button(
                        action: {},
                        label: {
                            Text("Take Offer")
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
                }
                .padding()
            }
            .onAppear {
                stablecoinFormatter.numberStyle = .currency
                stablecoinFormatter.maximumFractionDigits = 3
            }
        } else {
            Text("This Offer is not available.")
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
    let settlementmethods: [SettlementMethod]
    
    /**
     The currently `SettlementMethod` method, or `nil` of no `SettlementMethod` is currently selected.
     */
    @Binding var selectedSettlementMethod: SettlementMethod?
    
    /**
     The currency code of the offer's stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        ForEach(settlementmethods) { settlementMethod in
            
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
                    strokeColor: color,
                    stablecoinCurrencyCode: stablecoinCurrencyCode
                )
            }
            .accentColor(color)
        }
    }
}

/**
 Displays a card containing settlement method information that cannot be edited.
 */
struct ImmutableSettlementMethodCard: View {
    
    /**
     The `SettlementMethod`  that this card represents.
     */
    @State var settlementMethod: SettlementMethod
    
    /**
     The color of the stroke surrounding this card.
     */
    var strokeColor: Color
    
    /**
     The currency code of the currently selected stablecoin.
     */
    let stablecoinCurrencyCode: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(buildCurrencyDescription())
                    .bold()
                    .padding(1)
                Text(buildPriceDescription())
                    .bold()
                    .padding(1)
            }
            Spacer()
        }
        .padding(15)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(strokeColor, lineWidth: 1)
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

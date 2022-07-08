//
//  OfferView.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Displays information about a specific [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct OfferView: View {
    
    /**
     Controls whether the `DisclosureGroup` displaying a description of the offer direction is open.
     */
    @State private var isDirectionDescriptionExpanded = false
    /**
     Controls whether the `DisclosureGroup` displaying advanced details about the offer is open.
     */
    @State private var isAdvancedDetailsDescriptionExpanded = false
    
    /**
     The human readable symbol of the stablecoin for which the offer has been made.
     */
    let stablecoin = "STBL"
    
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s minimum amount.
     */
    let minimumAmount = "10,000"
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s maximum amount.
     */
    let maximumAmount = "20,000"
    
    /**
     The settlement methods that the maker is willing to accept.
     */
    let settlementMethods = [
        SettlementMethod(currency: "EUR", method: "SEPA", price: "0.94", id: "1"),
        SettlementMethod(currency: "USD", method: "SWIFT", price: "1.00", id: "2"),
        SettlementMethod(currency: "BSD", method: "SANDDOLLAR", price: "1.00", id: "3")
    ]
    
    /**
     The [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) about which this `OfferView` displays information.
     */
    @ObservedObject var offer: Offer
    
    var body: some View {
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
                            Text(buildDirectionDescriptionString())
                                .padding(.bottom, 1)
                        },
                        label: {
                            Text(buildDirectionString())
                                .font(.title)
                                .bold()
                        }
                    )
                    .accentColor(Color.primary)
                    OfferAmountView(minimum: minimumAmount, maximum: maximumAmount)
                    HStack {
                        Text("Settlement methods:")
                            .font(.title2)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .padding([.leading, .trailing, .top])
                SettlementMethodListView(stablecoin: stablecoin, settlementMethods: settlementMethods)
                    .padding(.leading)
                VStack {
                    DisclosureGroup(
                        isExpanded: $isAdvancedDetailsDescriptionExpanded,
                        content: {
                            // Note that the empty string should never be displayed, since a "not available" message is displayed if offer is nil.
                            Text("ID: " + offer.id.uuidString)
                                .padding(.bottom, 1)
                        },
                        label: {
                            Text("Advanced Details")
                                .font(.title2)
                                .bold()
                        }
                    )
                    .accentColor(Color.primary)
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
     */
    func buildDirectionString() -> String {
        var directionJoiner: String {
            switch offer.direction {
            case .buy:
                return "with"
            case .sell:
                return "for"
            }
        }
        return offer.direction.string + " " + stablecoin + " " + directionJoiner + " fiat"
    }
    
    /**
     Creates the text for the direction description within the direction `DisclosureGroup`.
     */
    func buildDirectionDescriptionString() -> String {
        // We should never get the empty string here because no offer information will be displayed if offer is nil
        return "This is a " + offer.direction.string + " offer: The maker of this offer wants to " + offer.direction.string.lowercased() + " " + stablecoin + " in exchange for fiat."
    }
}

/**
 A view that displays the minimum and maximum amount stablecoin that the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)  is willing to exchange.
 */
struct OfferAmountView: View {
    /**
     A human readable minimum stablecoin amount.
     */
    let minimum: String
    /**
     A human readable maximum stablecoin amount.
     */
    let maximum: String
    
    var body: some View {
        HStack {
            Text("Amount:")
                .font(.title2)
            Spacer()
        }
        .padding(.bottom, 2)
        if minimum == maximum {
            HStack {
                Text(minimum + " STBL")
                    .font(.title2).bold()
                Spacer()
            }
        } else {
            HStack {
                Text("Minimum: " + minimum + " STBL")
                    .font(.title2).bold()
                Spacer()
                
            }
            HStack {
                Text("Maximum: " + maximum + " STBL")
                    .font(.title2).bold()
                Spacer()
            }
        }
        
    }
}

/**
 A settlement method specified by the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) by which they are willing to send/receive payment
 */
struct SettlementMethod: Identifiable {
    /**
     The currency in which the maker is willing to send/receive payment.
     */
    let currency: String
    /**
     The method by which the currency specified in `currency` will be transferred from the stablecoin buyer to the stablecoin seller.
     */
    let method: String
    /**
     The amount of the currency specified in `currency` that the maker is willing to exchange for one stablecoin unit.
     */
    let price: String
    /**
     An ID that uniquely identifies this settlement method, so it can be consumed by SwiftUI's `ForEach`.
     */
    var id: String
}

/**
 Displays a horizontally scrolling list of `SettlementMethodView`s.
 */
struct SettlementMethodListView: View {
    /**
     The human readable symbol of the stablecoin for which the offer related to these settlement methods has been made.
     */
    let stablecoin: String
    /**
     The settlement methods to be displayed.
     */
    let settlementMethods: [SettlementMethod]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(settlementMethods) { settlementMethod in
                    SettlementMethodView(stablecoin: stablecoin, settlementMethod: settlementMethod)
                }
                .padding(5)
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
            OfferView(offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!)
            OfferView(offer: Offer.sampleOffers[Offer.sampleOfferIds[0]]!).preferredColorScheme(.dark)
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}

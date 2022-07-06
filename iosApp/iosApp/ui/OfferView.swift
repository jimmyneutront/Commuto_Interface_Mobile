//
//  OfferView.swift
//  iosApp
//
//  Created by jimmyt on 7/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

struct OfferView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDirectionDescriptionExpanded = false
    @State private var isAdvancedDetailsDescriptionExpanded = false
    
    var id: UUID
    
    let directionString = "Buy"
    let directionJointer = "with"
    let stablecoin = "STBL"
    let fiat = "FIAT"
    
    let minimumAmount = "10,000"
    let maximumAmount = "20,000"
    
    let settlementMethods = [
        SettlementMethod(currency: "EUR", method: "SEPA", price: "0.94", id: "1"),
        SettlementMethod(currency: "USD", method: "SWIFT", price: "1.00", id: "2"),
        SettlementMethod(currency: "BSD", method: "SANDDOLLAR", price: "1.00", id: "3")
    ]
    
    var offer: Offer? = Offer.sampleOffers[Offer.sampleOfferIds[0]]
    
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
                    .accentColor(colorScheme == .dark ? .white : .black)
                    OfferAmountView(minimum: minimumAmount, maximum: maximumAmount)
                }
                .padding()
                SettlementMethodListView(stablecoin: stablecoin, settlementMethods: settlementMethods)
                    .offset(x: 0, y: -10.0)
                VStack {
                    DisclosureGroup(
                        isExpanded: $isAdvancedDetailsDescriptionExpanded,
                        content: {
                            Text("ID: " + id.uuidString)
                                .padding(.bottom, 1)
                        },
                        label: {
                            Text("Advanced Details")
                                .font(.title2)
                                .bold()
                        }
                    )
                    .accentColor(colorScheme == .dark ? .white : .black)
                }
                .offset(x: 0.0, y: -20.0)
                .padding()
                Spacer()
            }
            .offset(x:0.0, y: -30.0)
        }
        .navigationBarTitle(Text("Offer"))
    }
    
    func buildDirectionString() -> String {
        return directionString + " " + stablecoin + " " + directionJointer + " " + fiat
    }
    
    func buildDirectionDescriptionString() -> String {
        return "This is a " + directionString + " offer: The maker of this offer wants to " + directionString.lowercased() + " " + stablecoin + " in exchange for " + fiat + "."
    }
}

struct OfferAmountView: View {
    let minimum: String
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

struct SettlementMethod: Identifiable {
    let currency: String
    let method: String
    let price: String
    var id: String
}

struct SettlementMethodListView: View {
    let stablecoin: String
    let settlementMethods: [SettlementMethod]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(settlementMethods) { settlementMethod in
                    SettlementMethodView(stablecoin: stablecoin, settlementMethod: settlementMethod)
                }
                .padding(5)
            }
            .padding(.leading)
        }
    }
}

struct SettlementMethodView: View {
    @Environment(\.colorScheme) var colorScheme
    let stablecoin: String
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
                .stroke(colorScheme == .dark ? .white : .black, lineWidth: 5)
        )
    }
    
    func buildCurrencyDescription() -> String {
        return settlementMethod.currency + " via " + settlementMethod.method
    }
    
    func buildPriceDescription() -> String {
        return "Price: " + settlementMethod.price + " " + settlementMethod.currency + "/" + stablecoin
    }
    
}

struct OfferView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            //OfferView(id: UUID())
            OfferView(id: UUID()).preferredColorScheme(.dark)
        }
    }
}

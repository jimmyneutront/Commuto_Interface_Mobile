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
struct EditOfferView: View {
    
    init(stablecoinCurrencyCode: String) {
        self.stablecoinCurrencyCode = stablecoinCurrencyCode
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
     The `SettlementMethod`s that the user has selected.
     */
    @State private var selectedSettlementMethods: [SettlementMethod] = []
    
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
                    selectedSettlementMethods: $selectedSettlementMethods
                )
                Button(
                    action: {
                        
                    },
                    label: {
                        Text("Edit Offer")
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
            .padding([.leading, .trailing])
        }
        .navigationTitle("Edit Offer")
    }
}

/**
 Displays a preview of `EditOfferView` with the stablecoin currency code "STBL".
 */
struct EditOfferView_Previews: PreviewProvider {
    static var previews: some View {
        EditOfferView(stablecoinCurrencyCode: "STBL")
    }
}

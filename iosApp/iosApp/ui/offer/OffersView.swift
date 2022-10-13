//
//  OffersView.swift
//  iosApp
//
//  Created by jimmyt on 5/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import SwiftUI

/**
 Displays the main list of offers as `OfferCardView`s in a `List` within a `NavigationView`.
 */
struct OffersView<Offer_TruthSource, SettlementMethod_TruthSource>: View where Offer_TruthSource: UIOfferTruthSource, SettlementMethod_TruthSource: UISettlementMethodTruthSource {
    
    /**
     An object adopting the `UIOfferTruthSource` protocol that acts as a single source of truth for all offer-related data.
     */
    @ObservedObject var offerTruthSource: Offer_TruthSource
    
    /**
     An object adopting `UISettlementMethodTruthSource` that acts as a single source of truth for all settlement-method-related data.
     */
    @ObservedObject var settlementMethodTruthSource: SettlementMethod_TruthSource
    
    /**
     The `StablecoinInformationRepository` that this `View` uses to get stablecoin name and currency code information. Defaults to `StablecoinInformationRepository.hardhatStablecoinInfoRepo` if no other value is provided.
     */
    let stablecoinInformationRepository = StablecoinInformationRepository.hardhatStablecoinInfoRepo
    
    var body: some View {
        NavigationView {
            Group {
                if offerTruthSource.offers.count > 0 {
                    List {
                        ForEach(offerTruthSource.offers.map { $0.1 }, id: \.id) { offer in
                            NavigationLink(destination: OfferView(offer: offer, offerTruthSource: offerTruthSource, settlementMethodTruthSource: settlementMethodTruthSource)) {
                                OfferCardView(
                                    offerDirection: offer.direction.string,
                                    stablecoinCode: stablecoinInformationRepository.getStablecoinInformation(chainID: offer.chainID, contractAddress: offer.stablecoin)?.currencyCode ?? "Unknown Stablecoin"
                                )
                            }
                        }
                    }
                } else {
                    VStack(alignment: .center) {
                        Text("There are no offers to display.")
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle(Text("Offers", comment: "Appears as a title above the list of open offers"))
            .toolbar {
                HStack {
                    Button(action: {}) {
                        NavigationLink(destination: OpenOfferView(offerTruthSource: offerTruthSource, settlementMethodViewModel: settlementMethodTruthSource)) {
                            Text("Open", comment: "The label of the button to open a new offer")

                        }
                    }
                    Button(action: {}) {
                        Text("Filter", comment: "The label of the button to filter the offers shown in the open offers list")
                    }
                }
            }
        }
    }
}

/**
 Displays a preview of `OffersView` with sample offers, in German.
 */
struct OffersView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OffersView(
                offerTruthSource: PreviewableOfferTruthSource(),
                settlementMethodTruthSource: PreviewableSettlementMethodTruthSource()
            )
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}

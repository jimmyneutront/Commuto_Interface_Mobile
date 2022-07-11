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
struct OffersView: View {
    
    /// The `OffersViewModel` that acts as a single source of truth for all offer-related data.
    @ObservedObject var offersViewModel: OffersViewModel
    
    let stablecoinInformationRepository = StablecoinInformationRepository.ethereumMainnetStablecoinInfoRepo
    
    var body: some View {
        NavigationView {
            List {
                ForEach(offersViewModel.offers.map { $0.1 }, id: \.id) { offer in
                    NavigationLink(destination: OfferView(offer: offer, offersViewModel: offersViewModel)) {
                        OfferCardView(
                            offerDirection: offer.direction.string,
                            stablecoinCode: stablecoinInformationRepository.getStablecoinInformation(chainID: offer.chainID, contractAddress: offer.stablecoin)?.currencyCode ?? "Unknown Stablecoin"
                        )
                    }
                }
            }
            .navigationTitle(Text("Offers", comment: "Appears as a title above the list of open offers"))
            .toolbar {
                HStack {
                    Button(action: {}) {
                        Text("Create", comment: "The label of the button to create a new offer")
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
                offersViewModel: OffersViewModel(
                    offerService: OfferService(databaseService: try! DatabaseService())
                )
            )
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}

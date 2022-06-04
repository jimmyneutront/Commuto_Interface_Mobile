//
//  OffersViewModel.swift
//  iosApp
//
//  Created by jimmyt on 5/31/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

class OffersViewModel: ObservableObject {
    
    let offerService: OfferService
    @Published var offers: [UUID: Offer]
    
    init(offerService: OfferService) {
        self.offerService = offerService
        offers = Offer.sampleOffers
    }
}

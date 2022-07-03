//
//  OffersViewModel.swift
//  iosApp
//
//  Created by jimmyt on 5/31/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 The Offers View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class OffersViewModel: OfferTruthSource, ObservableObject {
    
    /**
     A temporary initializer for use during development.
     */
    /*
    init() {
        offers = Offer.sampleOffers
    }
     */
    
    /**
     Initializes a new `OffersViewModel`.
     
     - Parameter offerService: An `OfferService` that adds and removes `Offer`s from this class's `offers` dictionary as offers are created, canceled and taken.
     */
    init(offerService: OfferService) {
        self.offerService = offerService
        offers = Offer.sampleOffers
    }
    
    /**
     The `OfferService` responsible for adding and removing `Offer`s from this class's `offers` dictionary as offers are created, canceled and taken.
     */
    let offerService: OfferService
    
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    @Published var offers: [UUID: Offer]
    
}

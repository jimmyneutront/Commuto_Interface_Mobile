//
//  PreviewableOfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 7/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 An `OfferTruthSource` implementation used for previewing user interfaces.
 */
class PreviewableOfferTruthSource: OfferTruthSource {
    
    /**
     Initializes a new `PreviewableOfferTruthSource` with sample offers.
     */
    init() {
        offers = Offer.sampleOffers
    }
    
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    @Published var offers: [UUID : Offer]
    
}

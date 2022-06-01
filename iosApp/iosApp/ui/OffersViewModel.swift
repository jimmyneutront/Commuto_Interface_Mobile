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
    @Published var offersDict: [UUID: Offer]
    
    init(offerService: OfferService) {
        self.offerService = offerService
        offersDict = offerService.offers
    }
}

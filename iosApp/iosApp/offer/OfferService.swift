//
//  OfferService.swift
//  iosApp
//
//  Created by jimmyt on 6/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

class OfferService {
    var offers = Offer.sampleOffers
    
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
        offers[event.id] = Offer(id: event.id, direction: "Buy", price: "1.004", pair: "USD/USDT")
    }
}

//
//  OfferService.swift
//  iosApp
//
//  Created by jimmyt on 6/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

class OfferService: OfferNotifiable {
    
    var viewModel: OffersViewModel? = nil
    
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
        DispatchQueue.main.sync {
            viewModel?.offers[event.id] = Offer(id: event.id, direction: "Buy", price: "1.004", pair: "USD/USDT")
        }
    }
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
        _ = DispatchQueue.main.sync {
            viewModel?.offers.removeValue(forKey: event.id)
        }
    }
    func handleOfferTakenEvent(_ event: OfferTakenEvent) {
        _ = DispatchQueue.main.sync {
            viewModel?.offers.removeValue(forKey: event.id)
        }
    }
    
}

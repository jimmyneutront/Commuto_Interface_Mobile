//
//  OfferService.swift
//  iosApp
//
//  Created by jimmyt on 6/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 The main Offer Service. It is responsible for processing and organizing offer-related data that it receives from `BlockchainService` and `P2PService` in order to maintain an accurate list of all open offers in `OffersViewModel`.
 */
class OfferService: OfferNotifiable {
    
    /**
     The `OffersViewModel` in which this is responsible for maintaining an accurate list of all open offers.
     */
    var viewModel: OffersViewModel? = nil
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`. Once notified, `OfferService` gets the ID of the new offer from `event`, creates a new `Offer` using the data stored in event, then synchronously maps the id to the new `Offer` in `viewModel`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferOpenedEvent` of which `OfferService` is being notified.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) {
        DispatchQueue.main.sync {
            viewModel?.offers[event.id] = Offer(id: event.id, direction: "Buy", price: "1.004", pair: "USD/USDT")
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferCanceledEvent`. Once notified, `OfferService` gets the ID of the now-canceled offer from `event` and then synchronously removes the `Offer` mapped to the ID specified in `event` from `viewModel`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferCanceledEvent` of which `OfferService` is being notified.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
        _ = DispatchQueue.main.sync {
            viewModel?.offers.removeValue(forKey: event.id)
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferTakenEvent`. Once notified, `OfferService` gets the ID of the now-taken offer from `event` and then synchronously removes the `Offer` mapped to the ID specified in `event` from `viewModel`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferTakenEvent` of which `OfferService` is being notified.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) {
        _ = DispatchQueue.main.sync {
            viewModel?.offers.removeValue(forKey: event.id)
        }
    }
    
}

//
//  OfferNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

protocol OfferNotifiable {
    
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent)
    
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent)
    
    func handleOfferTakenEvent(_ event: OfferTakenEvent)
    
}

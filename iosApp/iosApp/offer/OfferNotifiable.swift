//
//  OfferNotifiable.swift
//  iosApp
//
//  Created by jimmyt on 6/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

protocol OfferNotifiable {
    
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent)
    
    func handleOfferTakenEvent(_ event: OfferTakenEvent)
    
}

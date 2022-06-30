//
//  DatabaseOfferCanceledEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/30/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Represents an `OfferCanceledEvent` in a form that can be persistently stored in a database.
 
 -Properties:
    - id: The ID of the newly canceled offer, as Base64-`String` encoded bytes.
 */
struct DatabaseOfferCanceledEvent: Equatable {
    let id: String
}

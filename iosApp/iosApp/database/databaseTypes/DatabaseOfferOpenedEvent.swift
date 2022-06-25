//
//  DatabaseOfferOpenedEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/25/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Represents an `OfferOpenedEvent` in a form that can be persistently stored in a database.
 
 -Properties:
    - id: The ID of the newly opened offer, as Base64-`String` encoded bytes.
    - interfaceId: The interface ID belonging to the maker of the newly opened offer, as Base64-`String` encoded bytes.
 */
struct DatabaseOfferOpenedEvent: Equatable {
    let id: String
    let interfaceId: String
    /**
     Compares two `DatabaseOfferOpenedEvent`s for equality. Two `DatabaseOfferOpenedEvent`s are defined as equal if their `id` and `interfaceId` properties are equal.
     
     - Parameters:
        - lhs: The `DatabaseOfferOpenedEvent` on the left side of the equality operator.
        - rhs: The `DatabaseOfferOpenedEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether `lhs` and `rhs` are equal.
     */
    public static func == (lhs: DatabaseOfferOpenedEvent, rhs: DatabaseOfferOpenedEvent) -> Bool {
        return lhs.id == rhs.id && lhs.interfaceId == rhs.interfaceId
    }
}

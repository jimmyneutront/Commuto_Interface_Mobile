//
//  OfferEditedEvent.swift
//  iosApp
//
//  Created by jimmyt on 7/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 This class represents an [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) event, emitted by the CommutoSwap smart contract when the price or settlement methods of an open offer is edited.
 
 -Properties:
    - id: The ID of the edited offer, as a `UUID`.
 */
class OfferEditedEvent: Equatable {
    let id: UUID
    /**
     Creates a new `OfferEditedEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferEdited event.
     
     - Parameter result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferCanceledEvent`.
     */
    init?(_ result: EventParserResultProtocol) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        if resultId != nil {
            id = resultId!
        } else {
            return nil
        }
    }
    
    /**
    Compares two `OfferEditedEvent`s for equality. Two `OfferEditedEvent`s are defined as equal if their `id` properties are equal.
     
     - Parameters:
        - lhs: The `OfferEditedEvent` on the left side of the equality operator.
        - rhs: The `OfferEditedEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    static func == (lhs: OfferEditedEvent, rhs: OfferEditedEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

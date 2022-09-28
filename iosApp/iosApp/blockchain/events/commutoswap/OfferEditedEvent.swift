//
//  OfferEditedEvent.swift
//  iosApp
//
//  Created by jimmyt on 7/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 This class represents an [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) event, emitted by the CommutoSwap smart contract when the price or settlement methods of an open offer is edited.
 
 - Properties:
    - id: The ID of the edited offer, as a `UUID`.
    - chainID: The ID of the blockchain on which this event was emitted.
 */
class OfferEditedEvent: Equatable {
    let id: UUID
    let chainID: BigUInt
    /**
     Creates a new `OfferEditedEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferEdited](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeredited) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferEdited event.
     
     - Parameters:
        - result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferCanceledEvent`.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        if resultId != nil {
            id = resultId!
        } else {
            return nil
        }
        self.chainID = chainID
    }
    
    /**
     Creates a new `OfferEditedEvent` with the given `id` and `chainID`.
     */
    init(id: UUID, chainID: BigUInt) {
        self.id = id
        self.chainID = chainID
    }
    
    /**
    Compares two `OfferEditedEvent`s for equality. Two `OfferEditedEvent`s are defined as equal if their `id` and `chainID` properties are equal.
     
     - Parameters:
        - lhs: The `OfferEditedEvent` on the left side of the equality operator.
        - rhs: The `OfferEditedEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    static func == (lhs: OfferEditedEvent, rhs: OfferEditedEvent) -> Bool {
        return lhs.id == rhs.id && lhs.chainID == rhs.chainID
    }
}

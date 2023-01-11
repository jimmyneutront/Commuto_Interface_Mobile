//
//  OfferTakenEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 This class represents an [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) event, emitted by the CommutoSwap smart contract when an open offer is taken.
 
 - Properties:
    - id: The ID of the taken offer, as a `UUID`.
    - interfaceId: The [interface ID](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt#L70) belonging to the taker of the offer, as `Data`.
    - chainID: The ID of the blockchain on which this event was emitted.
 */
class OfferTakenEvent: Equatable {
    let id: UUID
    let interfaceId: Data
    let chainID: BigUInt
    /**
     Creates a new `OfferTakenEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferTaken event.
     
     - Parameters:
        - result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferTakenEvent`.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        let resultInterfaceId = result.decodedResult["takerInterfaceId"] as? Data
        if (resultId != nil && resultInterfaceId != nil) {
            id = resultId!
            interfaceId = resultInterfaceId!
        } else {
            return nil
        }
        self.chainID = chainID
    }
    
    /**
     Creates a new `OfferTakenEvent` given an offer ID as a `UUID`, an interface ID as `Data`, and a blockchain ID as a `BigUInt`.
     
     - Parameters:
        - id: The ID of the offer corresponding to this event, as a `UUID`.
        - interfaceID: The interface ID specified for the offer corresponding to this event, as `Data`.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init(id: UUID, interfaceID: Data, chainID: BigUInt) {
        self.id = id
        self.interfaceId = interfaceID
        self.chainID = chainID
    }
    
    /**
    Compares two `OfferTakenEvent`s for equality. Two `OfferTakenEvent`s are defined as equal if their `id`,  `interfaceId` and `chainID` properties are equal.
     
     - Parameters:
        - lhs: The `OfferTakenEvent` on the left side of the equality operator.
        - rhs: The `OfferTakenEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    static func == (lhs: OfferTakenEvent, rhs: OfferTakenEvent) -> Bool {
        return lhs.id == rhs.id && lhs.interfaceId == rhs.interfaceId && lhs.chainID == rhs.chainID
    }
}

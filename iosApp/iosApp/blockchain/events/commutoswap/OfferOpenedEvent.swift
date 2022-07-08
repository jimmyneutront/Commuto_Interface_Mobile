//
//  OfferOpenedEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 This class represents an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) event, emitted by the CommutoSwap smart contract when a new offer is opened.
 
 - Properties:
    - id: The ID of the newly opened offer, as a `UUID`.
    - interfaceId: The [interface ID](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt#L70) belonging to the maker of the newly opened offer, as `Data`.
    - chainID: The ID of the blockchain on which this event was emitted.
 */
class OfferOpenedEvent: Equatable {
    let id: UUID
    let interfaceId: Data
    let chainID: BigUInt
    /**
     Creates a new `OfferOpenedEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferOpened event.
     
     - Parameters:
        - result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferOpenedEvent`.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        let resultInterfaceId = result.decodedResult["interfaceId"] as? Data
        if (resultId != nil && resultInterfaceId != nil) {
            id = resultId!
            interfaceId = resultInterfaceId!
        } else {
            return nil
        }
        self.chainID = chainID
    }
    
    /**
    Compares two `OfferOpenedEvent`s for equality. Two `OfferOpenedEvent`s are defined as equal if their `id`, `interfaceId`, and `chainID` properties are equal.
     
     - Parameters:
        - lhs: The `OfferOpenedEvent` on the left side of the equality operator.
        - rhs: The `OfferOpenedEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    static func == (lhs: OfferOpenedEvent, rhs: OfferOpenedEvent) -> Bool {
        return lhs.id == rhs.id && lhs.interfaceId == rhs.interfaceId && lhs.chainID == rhs.chainID
    }
    
}

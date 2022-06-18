//
//  OfferTakenEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 This class represents an [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) event, emitted by the CommutoSwap smart contract when an open offer is taken.
 
 -Properties:
    - id: The ID of the taken offer, as a `UUID`.
    - interfaceId: The [interface ID](https://github.com/jimmyneutront/commuto-whitepaper/blob/d26697ab78a5b00bd9578bbea1f40796cda6f0b3/commuto-whitepaper.txt#L70) belonging to the taker of the offer, as `Data`.
 */

class OfferTakenEvent {
    let id: UUID
    let interfaceId: Data
    /**
     Creates a new `OfferTakenEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) event, or returns `nil` of the passed `EventParserResultProtocol` doesn't contain information from an OfferTaken event.
     
     - Parameter result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferTakenEvent`.
     */
    init?(_ result: EventParserResultProtocol) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        let resultInterfaceId = result.decodedResult["takerInterfaceId"] as? Data
        if (resultId != nil && resultInterfaceId != nil) {
            id = resultId!
            interfaceId = resultInterfaceId!
        } else {
            return nil
        }
    }
}

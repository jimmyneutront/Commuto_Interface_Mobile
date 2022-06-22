//
//  OfferOpenedEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 This class represents an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) event, emitted by the CommutoSwap smart contract when a new offer is opened.
 
 -Properties:
    - id: The ID of the newly opened offer, as a `UUID`.
    - interfaceId: The [interface ID](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt#L70) belonging to the maker of the newly opened offer, as `Data`.
 */
class OfferOpenedEvent {
    let id: UUID
    let interfaceId: Data
    /**
     Creates a new `OfferOpenedEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferOpened event.
     
     - Parameter result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `OfferOpenedEvent`.
     */
    init?(_ result: EventParserResultProtocol) {
        let resultId = UUID.from(data: result.decodedResult["offerID"] as? Data)
        let resultInterfaceId = result.decodedResult["interfaceId"] as? Data
        if (resultId != nil && resultInterfaceId != nil) {
            id = resultId!
            interfaceId = resultInterfaceId!
        } else {
            return nil
        }
    }
}

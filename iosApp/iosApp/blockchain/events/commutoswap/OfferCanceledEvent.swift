//
//  OfferCanceledEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 This class represents an [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) event, emitted by the CommutoSwap smart contract when an open offer is canceled.
 
 -Properties:
    - id: The ID of the canceled offer, as a `UUID`.
 */
class OfferCanceledEvent {
    let id: UUID
    /**
     Creates a new `OfferCanceledEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferCanceled event.
     
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
}

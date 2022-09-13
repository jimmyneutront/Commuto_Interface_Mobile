//
//  SellerClosedEvent.swift
//  iosApp
//
//  Created by jimmyt on 9/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Represents a [SellerClosed](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#sellerclosed) event, emitted by the CommutoSwap smart contract when the seller in a swap closes the swap.
 */
class SellerClosedEvent {
    /**
     The ID of the swap that the seller has closed.
     */
    let id: UUID
    /**
     The ID of the blockchain on which the event was emitted.
     */
    let chainID: BigUInt
    /**
     Creates a new `SellerClosedEvent` given a web3swift `EventParserResultProtocol` containing information from a [SellerClosed](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#sellerclosed) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from a SellerClosed event.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        guard let resultID = UUID.from(data: result.decodedResult["swapID"] as? Data) else {
            return nil
        }
        id = resultID
        self.chainID = chainID
    }
    /**
     Creates a new `SellerClosedEvent` with the given `id` and `chainID`.
     */
    init(id: UUID, chainID: BigUInt) {
        self.id = id
        self.chainID = chainID
    }
}

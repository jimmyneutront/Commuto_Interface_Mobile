//
//  SwapFilledEvent.swift
//  iosApp
//
//  Created by jimmyt on 9/5/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Represents a [SwapFilled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swapfilled) event, emitted by the CommutoSwap smart contract when a swap is filled.
 */
class SwapFilledEvent {
    /**
     The ID of the filled swap.
     */
    let id: UUID
    /**
     The ID of the blockchain on which the event was emitted.
     */
    let chainID: BigUInt
    /**
     Creates a new `SwapFilledEvent` given a web3swift `EventParserResultProtocol` containing information from a [SwapFilled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swapfilled) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an SwapFilled event.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        guard let resultID = UUID.from(data: result.decodedResult["swapID"] as? Data) else {
            return nil
        }
        id = resultID
        self.chainID = chainID
    }
    /**
     Creates a new `SwapFilled` event with the given `id` and `chainID`
     */
    init(id: UUID, chainID: BigUInt) {
        self.id = id
        self.chainID = chainID
    }
    
}

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
     The hash of the transaction that emitted this event, as a lowercae hex string with a "0x" prefix.
     */
    let transactionHash: String
    /**
     Creates a new `SwapFilledEvent` given a web3swift `EventParserResultProtocol` containing information from a [SwapFilled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swapfilled) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from a SwapFilled event.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        guard let resultID = UUID.from(data: result.decodedResult["swapID"] as? Data) else {
            return nil
        }
        id = resultID
        self.chainID = chainID
        guard var transactionHash = result.transactionReceipt?.transactionHash.toHexString().lowercased() else {
            return nil
        }
        if !transactionHash.starts(with: "0x") {
            transactionHash = "0x" + transactionHash
        }
        self.transactionHash = transactionHash
    }
    /**
     Creates a new `SwapFilledEvent` with the given `id` and `chainID`.
     */
    init(id: UUID, chainID: BigUInt, transactionHash: String) {
        self.id = id
        self.chainID = chainID
        self.transactionHash = transactionHash
    }
    
}

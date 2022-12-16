//
//  OfferCanceledEvent.swift
//  iosApp
//
//  Created by jimmyt on 6/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 This class represents an [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) event, emitted by the CommutoSwap smart contract when an open offer is canceled.
 
 - Properties:
    - id: The ID of the canceled offer, as a `UUID`.
    - chainID: The ID of the blockchain on which this event was emitted.
    - transactionHash: The hash of the transaction that emitted this event, as a lowercase  hex string with a "0x" prefix.
 */
class OfferCanceledEvent: Equatable {
    let id: UUID
    let chainID: BigUInt
    let transactionHash: String
    /**
     Creates a new `OfferCanceledEvent` given a web3swift `EventParserResultProtocol` containing information from an [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an OfferCanceled event or does not have a valid transaction hash.
     
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
        guard var transactionHash = result.transactionReceipt?.transactionHash.toHexString().lowercased() else {
            return nil
        }
        if !transactionHash.starts(with: "0x") {
            transactionHash = "0x" + transactionHash
        }
        self.transactionHash = transactionHash
    }
    
    /**
    Compares two `OfferCanceledEvent`s for equality. Two `OfferCanceledEvent`s are defined as equal if their `id`, `chainID` and `transactionHash` properties are equal.
     
     - Parameters:
        - lhs: The `OfferCanceledEvent` on the left side of the equality operator.
        - rhs: The `OfferCanceledEvent` on the right side of the equality operator.
     
     - Returns: A `Bool` indicating whether or not `lhs` and `rhs` are equal.
     */
    static func == (lhs: OfferCanceledEvent, rhs: OfferCanceledEvent) -> Bool {
        return lhs.id == rhs.id && lhs.chainID == rhs.chainID && lhs.transactionHash == rhs.transactionHash
    }
}

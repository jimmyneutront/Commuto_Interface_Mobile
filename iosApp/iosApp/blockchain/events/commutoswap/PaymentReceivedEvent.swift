//
//  PaymentReceivedEvent.swift
//  iosApp
//
//  Created by jimmyt on 9/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Represents a [PaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#paymentreceived) event, emitted by the CommutoSwap smart contract when the seller in a swap reports that they have received fiat payment from  the maker.
 */
class PaymentReceivedEvent {
    /**
     The ID of the swap for which payment has been received.
     */
    let id: UUID
    /**
     The ID of the blockchain on which the event was emitted.
     */
    let chainID: BigUInt
    /**
     Creates a new `PaymentReceivedEvent` given a web3swift `EventParserResultProtocol` containing information from a [PaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#paymentreceived) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from a PaymentReceived event.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        guard let resultID = UUID.from(data: result.decodedResult["swapID"] as? Data) else {
            return nil
        }
        id = resultID
        self.chainID = chainID
    }
    /**
     Creates a new `PaymentReceivedEvent` with the given `id` and `chainID`.
     */
    init(id: UUID, chainID: BigUInt) {
        self.id = id
        self.chainID = chainID
    }
}

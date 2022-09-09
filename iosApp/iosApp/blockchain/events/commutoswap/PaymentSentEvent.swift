//
//  PaymentSentEvent.swift
//  iosApp
//
//  Created by jimmyt on 9/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Represents a [PaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#paymentsent) event, emitted by the CommutoSwap smart contract when the buyer in a swap reports that they have sent fiat payment.
 */
class PaymentSentEvent {
    /**
     The ID of the swap for which payment has been sent.
     */
    let id: UUID
    /**
     The ID of the blockchain on which the event was emitted.
     */
    let chainID: BigUInt
    /**
     Creates a new `PaymentSentEvent` given a web3swift `EventParserResultProtocol` containing information from a [PaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#paymentsent) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from a PaymentSent event.
     */
    init?(_ result: EventParserResultProtocol, chainID: BigUInt) {
        guard let resultID = UUID.from(data: result.decodedResult["swapID"] as? Data) else {
            return nil
        }
        id = resultID
        self.chainID = chainID
    }
    /**
     Creates a new `PaymentSentEvent` with the given `id` and `chainID`.
     */
    init(id: UUID, chainID: BigUInt) {
        self.id = id
        self.chainID = chainID
    }
}

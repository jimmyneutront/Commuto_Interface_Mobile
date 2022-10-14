//
//  ValidatedNewSwapData.swift
//  iosApp
//
//  Created by jimmyt on 8/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt

/**
 Validated user-submitted data for taking an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct ValidatedNewSwapData {
    /**
     The stablecoin amount that the user will buy/sell.
     */
    let takenSwapAmount: BigUInt
    /**
     The settlement method, specified and accepted by the maker, by which the user will send/receive payment to/from the maker.
     */
    let makerSettlementMethod: SettlementMethod
    /**
     One of the user's settlement methods which has the same method and currency properties as `makerSettlementMethod`,  and contains the user's private settlement method details, which will be sent to the maker.
     */
    let takerSettlementMethod: SettlementMethod
}

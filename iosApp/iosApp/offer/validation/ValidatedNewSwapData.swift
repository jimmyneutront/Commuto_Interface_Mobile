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
     The settlement method by which the user will send/receive payment to/from the maker.
     */
    let settlementMethod: SettlementMethod
}

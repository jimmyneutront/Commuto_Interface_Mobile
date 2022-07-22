//
//  ValidatedNewOfferData.swift
//  iosApp
//
//  Created by jimmyt on 7/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Validated user-submitted data for a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct ValidatedNewOfferData: Equatable {
    /**
     The contract address of the stablecoin for which the new offer will be made.
     */
    let stablecoin: EthereumAddress
    /**
     The `StablecoinInformation` struct for the stablecoin for which the new offer will be made.
     */
    let stablecoinInformation: StablecoinInformation
    /**
     The minimum stablecoin amount for the new offer.
     */
    let minimumAmount: BigUInt
    /**
     The maximum stablecoin amount for the new offer.
     */
    let maximumAmount: BigUInt
    /**
     The security deposit amount for the new offer.
     */
    let securityDepositAmount: BigUInt
    /**
     The current service fee rate, as a percentage times 100.
     */
    let serviceFeeRate: BigUInt
    /**
     The minimum service fee for the new offer.
     */
    let serviceFeeAmountLowerBound: BigUInt
    /**
     The maximum service fee for the new offer.
     */
    let serviceFeeAmountUpperBound: BigUInt
    /**
     The direction for the new offer.
     */
    let direction: OfferDirection
    /**
     The settlement methods for the new offer.
     */
    let settlementMethods: [SettlementMethod]
    
}

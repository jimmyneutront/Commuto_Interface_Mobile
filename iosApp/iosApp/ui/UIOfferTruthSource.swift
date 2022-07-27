//
//  UIOfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 7/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data in an application with a graphical user interface..
 */
protocol UIOfferTruthSource: OfferTruthSource, ObservableObject {
    /**
     Indicates whether this is currently getting the current service fee rate.
     */
    var isGettingServiceFeeRate: Bool { get set }
    /**
     Indicates whether we are currently opening an offer, and if so, the point of the [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) we are currently in.
     */
    var openingOfferState: OpeningOfferState { get set }
    /**
     Attempts to get the current service fee rate and set `serviceFeeRate` equal to the result.
     */
    func updateServiceFeeRate()
    /**
     The `Error` that occured during the offer creation process, or `nil` if no such error has occured.
     */
    var openingOfferError: Error? { get set }
    /**
     Attempts to open a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    func openOffer(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod]
    )
}
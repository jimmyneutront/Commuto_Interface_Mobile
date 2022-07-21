//
//  OfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 6/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data.
 */
protocol OfferTruthSource: ObservableObject {
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    var offers: [UUID: Offer] { get set }
    /**
     The current [service fee rate](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt) as a percentage times 100, or `nil` if the current service fee rate is not known.
     */
    var serviceFeeRate: BigUInt? { get set }
    /**
     Indicates whether this is currently getting the current service fee rate.
     */
    var isGettingServiceFeeRate: Bool { get set }
    /**
     Attempts to get the current service fee rate and set `serviceFeeRate` equal to the result.
     */
    func updateServiceFeeRate()
}

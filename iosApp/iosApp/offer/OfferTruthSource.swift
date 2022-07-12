//
//  OfferTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 6/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data.
 */
protocol OfferTruthSource: ObservableObject {
    /**
     A dictionary mapping offer IDs (as `UUID`s) to `Offer`s, which is the single source of truth for all open-offer-related data.
     */
    var offers: [UUID: Offer] { get set }
}

//
//  TestOfferTruthSource.swift
//  iosAppTests
//
//  Created by jimmyt on 9/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
@testable import iosApp

/**
 A basic `OfferTruthSource` implementation for testing.
 */
class TestOfferTruthSource: OfferTruthSource {
    var serviceFeeRate: BigUInt?
    var offers: [UUID: Offer] = [:]
}

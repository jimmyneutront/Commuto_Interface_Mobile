//
//  TestSwapTruthSource.swift
//  iosAppTests
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
@testable import iosApp

/**
 A basic `SwapTruthSource` implementation for testing.
 */
class TestSwapTruthSource: SwapTruthSource {
    var swaps: [UUID : Swap] = [:]
}

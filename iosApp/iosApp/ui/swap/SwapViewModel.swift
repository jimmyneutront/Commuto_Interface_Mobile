//
//  SwapViewModel.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 The Swap View Model, the single source of truth for all offer related data.
 */
class SwapViewModel: SwapTruthSource {
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swaps`s, which is the single source of truth for all swap-related data.
     */
    var swaps: [UUID : Swap] = [:]
}

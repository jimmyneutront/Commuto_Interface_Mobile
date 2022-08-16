//
//  SwapViewModel.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 The Swap View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class SwapViewModel: UISwapTruthSource {
    
    /**
     Initializes a new `SwapViewModel`.
     */
    init() {
        swaps = Swap.sampleSwaps
    }
    
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swaps`s, which is the single source of truth for all swap-related data.
     */
    var swaps: [UUID : Swap] = [:]
}

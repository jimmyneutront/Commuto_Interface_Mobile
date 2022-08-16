//
//  PreviewableSwapTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 A `UISwapTruthSource` implementation used for previewing user interfaces.
 */
class PreviewableSwapTruthSource: UISwapTruthSource {
    /**
     Initializes a new `PreviewableSwapTruthSource` with sample swaps.
     */
    init() {
        swaps = Swap.sampleSwaps
    }
    
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swap`s, which is the single source of truth for all swap-related data.
     */
    @Published var swaps: [UUID : Swap]
}

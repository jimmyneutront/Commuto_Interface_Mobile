//
//  SwapTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for swap-related data.
 */
protocol SwapTruthSource {
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swap`s, which is the single source of truth for all swap-related data.
     */
    var swaps: [UUID: Swap] { get set }
}

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
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func fillSwap(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentSent(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func reportPaymentReceived(swap: Swap) {}
    
    /**
     Not used since this class is for previewing user interfaces, but required for adoption of `UISwapTruthSource`.
     */
    func closeSwap(swap: Swap) {}
}

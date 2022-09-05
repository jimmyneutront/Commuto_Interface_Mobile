//
//  SwapViewModel.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import PromiseKit

/**
 The Swap View Model, the single source of truth for all offer related data. It is observed by offer-related views.
 */
class SwapViewModel: UISwapTruthSource {
    
    /**
     Initializes a new `SwapViewModel`.
     */
    init(swapService: SwapService) {
        self.swapService = swapService
        swaps = Swap.sampleSwaps
    }
    
    /**
     SwapViewModel's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "SwapViewModel")
    
    /**
     The `SwapService` used for completing the swap process for `Swap`s in `swaps`.
     */
    let swapService: SwapService
    
    /**
     A dictionary mapping swap IDs (as `UUID`s) to `Swaps`s, which is the single source of truth for all swap-related data.
     */
    var swaps: [UUID : Swap] = [:]
    
    /**
     Sets the `fillingSwapState` property of `swap` to `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` of which to set the `fillingSwapState`.
        - state: The value to which the `Swap`'s `fillingSwapState` will be set.
     */
    private func setFillingSwapState(swap: Swap, state: FillingSwapState) {
        DispatchQueue.main.async {
            swap.fillingSwapState = state
        }
    }
    
    /**
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to fill.
     */
    func fillSwap(
        swap: Swap
    ) {
        setFillingSwapState(swap: swap, state: .checking)
        Promise<Void> { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("fillSwap: filling \(swap.id.uuidString)")
                swapService.fillSwap(
                    swapToFill: swap,
                    afterPossibilityCheck: { self.setFillingSwapState(swap: swap, state: .approving) },
                    afterTransferApproval: { self.setFillingSwapState(swap: swap, state: .filling) }
                ).pipe(to: seal.resolve)
            }
        }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] in
            logger.notice("fillSwap: successfully filled swap \(swap.id.uuidString)")
            setFillingSwapState(swap: swap, state: .completed)
        }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
            logger.error("fillSwap: got error during fillSwap call for \(swap.id.uuidString). Error: \(error.localizedDescription)")
            swap.fillingSwapError = error
            setFillingSwapState(swap: swap, state: .error)
        }
    }
}

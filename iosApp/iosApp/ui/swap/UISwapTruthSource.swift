//
//  UISwapTruthSource.swift
//  iosApp
//
//  Created by jimmyt on 8/15/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 A protocol that a structure or class must adopt in order to act as a single source of truth for open-offer-related data in an application with a graphical user interface.
 */
protocol UISwapTruthSource: SwapTruthSource, ObservableObject {
    
    /**
     Attempts to fill a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to fill.
     */
    func fillSwap(swap: Swap)
    
}

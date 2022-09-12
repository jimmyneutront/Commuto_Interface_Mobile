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
    
    /**
     Attempts to report that a buyer has sent fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the buyer in `swap`.
     
     - Parameter swap: The `Swap` to fill.
     */
    func reportPaymentSent(swap: Swap)
    
    /**
     Attempts to report that a seller has received fiat payment for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). This may only be used by the seller in `swap`.
     
     - Parameter swap: The `Swap` to fill.
     */
    func reportPaymentReceived(swap: Swap)
    
    /**
     Attempts to close a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     - Parameter swap: The `Swap` to close.
     */
    func closeSwap(swap: Swap)
}

//
//  FillingSwapState.swift
//  iosApp
//
//  Created by jimmyt on 9/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently filling a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). If we are, then this indicates the part of the swap filling process we are currently in.
 */
enum FillingSwapState {
    /**
     Indicates that we are not currently filling the corresponding swap.
     */
    case none
    /**
     Indicates that we are currently checking if we can fill the swap.
     */
    case checking
    /**
     Indicates that we are currently approving the token transfer to fill the corresponding swap.
     */
    case approving
    /**
     Indicates that we are currently calling CommutoSwap's [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) function for the swap.
     */
    case filling
    /**
     Indicates that we have filled the corresponding swap.
     */
    case completed
    /**
     Indicates that we encountered an error while filling the corresponding swap.
     */
    case error
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used.
            return "Press Fill Swap to fill the swap"
        case .checking:
            return "Checking that the swap can be filled..."
        case .approving:
            return "Approving token transfer..."
        case .filling:
            return "Filling the offer..."
        case .completed:
            return "Swap successfully filled."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
}

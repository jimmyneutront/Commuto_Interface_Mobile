//
//  ClosingSwapState.swift
//  iosApp
//
//  Created by jimmyt on 9/12/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently closing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). If we are, then this indicates the part of the swap closing process we are currently in.
 */
enum ClosingSwapState {
    /**
     Indicates that we are not currently closing the corresponding swap.
     */
    case none
    /**
     Indicates that we are currently checking if we can close the corresponding swap.
     */
    case checking
    /**
     Indicates that we are currently calling CommutoSwap's [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) function for the swap.
     */
    case closing
    /**
     Indicates that we have closed the corresponding swap.
     */
    case completed
    /**
     Indicates that we encountered an error while closing the corresponding swap.
     */
    case error
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used.
            return "Press Close Swap to close the swap"
        case .checking:
            return "Checking that swap can be closed..."
        case .closing:
            return "Closing swap..."
        case .completed:
            return "Successfully closed swap."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
}

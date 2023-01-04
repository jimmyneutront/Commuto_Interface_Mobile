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
     Indicates that we are currently checking if we can call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for the swap.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for the corresponding swap.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for the corresponding swap, and we are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have called [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for the corresponding swap, and that the transaction to do so has been confirmed.
     */
    case completed
    /**
     Indicates that we encountered an error while calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for the corresponding swap.
     */
    case error
    
    /**
     Returns a `String` corresponding to a particular case of `ReportingPaymentSentState`. This is primarily used for database storage.
     */
    var asString: String {
        switch self {
        case .none:
            return "none"
        case .validating:
            return "validating"
        case .sendingTransaction:
            return "sendingTransaction"
        case .awaitingTransactionConfirmation:
            return "awaitingTransactionConfirmation"
        case .completed:
            return "completed"
        case .error:
            return "error"
        }
    }
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used.
            return "Press Close Swap to close the swap"
        case .validating:
            return "Checking that swap can be closed..."
        case .sendingTransaction:
            return "Closing swap..."
        case .awaitingTransactionConfirmation:
            return "Waiting for confirmation..."
        case .completed:
            return "Successfully closed swap."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
    
}

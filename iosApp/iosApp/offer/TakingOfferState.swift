//
//  TakingOfferState.swift
//  iosApp
//
//  Created by jimmyt on 8/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently taking an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer). If we are, then this indicates the part of the offer taking process we are currently in.
 */
enum TakingOfferState {
    /**
     Indicates that we are not currently taking the corresponding offer.
     */
    case none
    /**
     Indicates that we are currently checking whether the corresponding offer can be taken.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will take the corresponding offer.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will take the corresponding offer, and we are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have taken the corresponding offe, and the transaction that did so has been confirmed..
     */
    case completed
    /**
     Indicates that we encountered an error while taking the corresponding offer.
     */
    case error
    
    /**
     Returns a `String` corresponding to a particular case of `TakingOfferState`.
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
            return "Press Take Offer to take the offer"
        case .validating:
            return "Validating swap data..."
        case .sendingTransaction:
            return "Taking the Offer..."
        case .awaitingTransactionConfirmation:
            return "Waiting for confirmation..."
        case .completed:
            return "Offer successfully taken."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
}

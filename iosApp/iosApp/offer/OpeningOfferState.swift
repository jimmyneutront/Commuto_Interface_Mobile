//
//  OpeningOfferState.swift
//  iosApp
//
//  Created by jimmyt on 7/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently opening a new offer. If we are, then this indicates the part of the [offer opening process](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) we are currently in.
 */
enum OpeningOfferState {
    /**
     Indicates that we are NOT currently opening the corresponding offer.
     */
    case none
    /**
     Indicates that we are currently checking whether the corresponding offer can be opened.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will open the corresponding offer.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will open the corresponding offer, and we are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have opened the corresponding offer, and the transaction that did so has been confirmed
     */
    case completed
    /**
     Indicates that we encountered an error while opening the corresponding offer.
     */
    case error
    
    /**
     Returns a `String` corresponding to a particular case of `OpeningOfferState`.
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
     A human-readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used
            return "Press Open Offer to open the offer."
        case .validating:
            return "Validating offer data..."
        case .sendingTransaction:
            return "Opening the Offer..."
        case .awaitingTransactionConfirmation:
            return "Waiting for confirmation..."
        case .completed:
            return "Offer successfully opened."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed
        }
    }
    
}

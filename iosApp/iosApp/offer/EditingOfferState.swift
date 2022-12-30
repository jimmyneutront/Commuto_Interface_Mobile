//
//  EditingOfferState.swift
//  iosApp
//
//  Created by jimmyt on 8/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently editing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer). If we are, then this indicates the part of the offer editing process we are currently in. Note that this is only used for offers made by the user of this interface.
 */
enum EditingOfferState {
    /**
     Indicates that we are NOT currently editing the corresponding offer.
     */
    case none
    /**
     Indicates that we are currently checking whether the corresponding offer can be edited.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will edit the corresponding offer.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will edit the corresponding offer, and we are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have edited the corresponding offer, and the transaction that did so has been confirmed.
     */
    case completed
    /**
     Indicates that we encountered an error while editing the corresponding offer.
     */
    case error
    
    /**
     Returns a `String` corresponding to a particular case of `EditingOfferState`.
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
    
}

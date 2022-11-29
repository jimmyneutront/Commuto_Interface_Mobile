//
//  CancelingOfferState.swift
//  iosApp
//
//  Created by jimmyt on 8/4/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently canceling an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer). If we are, then this indicates the part of the offer cancellation process we are currently in. Note that this is only used for offers made by the user of this interface.
 */
enum CancelingOfferState {
    /**
     Indicates that we are NOT currently canceling the corresponding offer.
     */
    case none
    /**
     Indicates that we are currently checking whether the corresponding offer can be canceled.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will cancel the corresponding offer.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will cancel the corresponding offer, and are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have canceled the corresponding offer, and the transaction that did so has been confirmed.
     */
    case completed
    /**
     Indicates that we encountered an error while canceling the corresponding offer.
     */
    case error
}

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
     Indicates that we are currently canceling the corresponding offer.
     */
    case canceling
    /**
     Indicates that we have canceled the corresponding offer.
     */
    case completed
    /**
     Indicates that we encountered an error while canceling the corresponding offer.
     */
    case error
}

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
     Indicates that the corresponding offer is open and not currently being canceled.
     */
    case none
    /**
     Indicates that the corresponding offer is currently being canceled.
     */
    case canceling
    /**
     Indicates that the corresponding offer has been canceled.
     */
    case completed
    /**
     Indicates that an error was encountered during offer cancellation.
     */
    case error
}

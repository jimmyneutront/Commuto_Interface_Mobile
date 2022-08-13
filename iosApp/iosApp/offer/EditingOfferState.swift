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
     Indicates that we are currently editing the corresponding offer.
     */
    case editing
    /**
     Indicates that we have edited the corresponding offer.
     */
    case completed
    /**
     Indicates that we encountered an exception while editing the corresponding offer.
     */
    case error
}

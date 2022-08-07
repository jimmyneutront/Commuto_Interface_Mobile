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
     Indicates that the corresponding offer is not currently being edited.
     */
    case none
    /**
     Indicates that the corresponding offer is currently being edited.
     */
    case editing
    /**
     Indicates that the corresponding offer has been edited.
     */
    case completed
    /**
     Indicates that an error was encountered during offer editing.
     */
    case error
}

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
     Indicates that we are currently validating user-submitted data for taking the corresponding offer.
     */
    case validating
    /**
     Indicates that we are currently checking if the offer is open and not taken.
     */
    case checking
    /**
     Indicates that we are currently creating a new key pair and `Swap` object for the new swap.
     */
    case creating
    /**
     Indicates that we are currently saving the new swap in persistent storage.
     */
    case storing
    /**
     Indicates that we are currently approving the token transfer to take the corresponding offer.
     */
    case approving
    /**
     Indicates that we are currently calling CommutoSwap's [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer) function for the new offer.
     */
    case taking
    /**
     Indicates that we have taken the corresponding offer.
     */
    case completed
    /**
     Indicates that we encountered an error while taking the corresponding offer.
     */
    case error
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used.
            return "Press Take Offer to take the offer"
        case .validating:
            return "Validating swap data..."
        case .checking:
            return "Checking offer availability..."
        case .creating:
            return "Creating a new key pair and swap object..."
        case .storing:
            return "Saving the new swap..."
        case .approving:
            return "Approving token transfer..."
        case .taking:
            return "Taking the offer..."
        case .completed:
            return "Offer successfully taken"
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
}

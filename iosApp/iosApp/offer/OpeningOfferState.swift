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
     Indicates that we are not currently opening a new offer.
     */
    case none
    /**
     Indicates that we are currently validating the user's submitted data for the new offer.
     */
    case validating
    /**
     Indicates that we are currently creating a new key pair, ID, and `Offer` object for the new offer.
     */
    case creating
    /**
     Indicates that we are currently saving the new offer in persistent storage.
     */
    case storing
    /**
     Indicates that we are currently approving the token transfer for opening the new offer.
     */
    case approving
    /**
     Indicates that we are currently calling CommutoSwap's [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) function for the new offer.
     */
    case opening
    /**
     Indicates that we have successfully opened the new offer.
     */
    case completed
    /**
     Indicates that we encountered an exception during offer creation.
     */
    case error
    
    /**
     A human-readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used
            return "Press Open Offer to open the offer"
        case .validating:
            return "Validating offer data..."
        case .creating:
            return "Creating a new key pair, offer ID and offer object..."
        case .storing:
            return "Saving the new offer..."
        case .approving:
            return "Approving token transfer..."
        case .opening:
            return "Opening the new offer..."
        case .completed:
            return "Offer successfully opened"
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed
        }
    }
    
}

//
//  OpenOfferValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/6/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that `offer` can be opened.
 
 This function ensures that:
    - the user of this interface is the maker of `offer`.
    - `offer` is in the `OfferState.awaitingOpening` state.
    - `offer` is not already being opened.
 
 - Parameter offer: The `Offer` to be validated for opening.

 - Throws: An `OfferDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateOfferForOpening(offer: Offer) throws {
    guard offer.isUserMaker else {
        throw OfferDataValidationError(desc: "You can only open your own offers")
    }
    guard offer.state == .awaitingOpening else {
        throw OfferDataValidationError(desc: "This Offer cannot currently be opened.")
    }
    guard offer.openingOfferState == .none || offer.openingOfferState == .validating || offer.openingOfferState == .error else {
        throw OfferDataValidationError(desc: "This Offer is already being opened.")
    }
}

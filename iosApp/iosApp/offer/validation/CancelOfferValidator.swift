//
//  CancelOfferValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that `offer` can be canceled.
 
 This function ensures that:
    - the user of this interface is the maker of `offer`.
    - `offer` is not taken.
    - `offer` has not been canceled.
    - `offer` is not already being canceled.
 
 - Parameter offer: The `Offer` to be validated for cancellation.
 
 - Throws: An `OfferDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateOfferForCancellation(offer: Offer) throws {
    guard offer.isUserMaker else {
        throw OfferDataValidationError(desc: "You can only cancel your own offers.")
    }
    guard !offer.isTaken else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is taken and cannot be canceled.")
    }
    guard offer.isCreated else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is already canceled")
    }
    guard (offer.cancelingOfferState == .none || offer.cancelingOfferState == .validating || offer.cancelingOfferState == .error) else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is already being canceled.")
    }
}

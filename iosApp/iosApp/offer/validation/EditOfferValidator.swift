//
//  EditOfferValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that `offer` can be edited.
 
 This function ensures that:
    - the user of this interface is the maker of `offer`.
    - `offer` is not taken.
    - `offer`has not been canceled.
    - `offer` is not already being edited.
 
 - Parameter offer: The `Offer` to be validated for editing.
 
 - Throws: An `OfferDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateOfferForEditing(offer: Offer) throws {
    guard offer.isUserMaker else {
        throw OfferDataValidationError(desc: "You can only edit your own offers.")
    }
    guard !offer.isTaken else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is already taken.")
    }
    guard offer.isCreated else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is already canceled")
    }
    guard (offer.editingOfferState == .validating) else {
        throw OfferDataValidationError(desc: "Offer \(offer.id.uuidString) is already being edited.")
    }
}

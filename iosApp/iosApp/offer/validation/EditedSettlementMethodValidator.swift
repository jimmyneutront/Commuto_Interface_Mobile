//
//  NewSettlementMethodValidator.swift
//  iosApp
//
//  Created by jimmyt on 8/6/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Validates edited settlement methods for an offer made by the user of this interface.
 
 This function ensures that:
    - the user has selected at least one settlement method
    - the user has specified a price for each selected settlement method
    - the user has supplied their information for each selected settlement method.
 
 - Parameter settlementMethods: The `Array` of `SettlementMethod`s to be validated.
 
 - Returns: An `Array` of validated `SettlementMethod`s
 
 - Throws An `EditedSettlementMethodValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateEditedSettlementMethods(
    _ settlementMethods: [SettlementMethod]
) throws -> [SettlementMethod] {
    guard !settlementMethods.isEmpty else {
        throw EditedSettlementMethodValidationError(desc: "You must specify at leat one settlement method.")
    }
    try settlementMethods.forEach { settlementMethod in
        guard settlementMethod.price != "" else {
            throw EditedSettlementMethodValidationError(desc: "You must specify a price for each settlement method you select.")
        }
        guard settlementMethod.privateData != nil else {
            throw NewOfferDataValidationError(desc: "You must supply your information for each settlement method you select.")
        }
    }
    return settlementMethods
}

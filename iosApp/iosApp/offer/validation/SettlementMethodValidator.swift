//
//  SettlementMethodValidator.swift
//  iosApp
//
//  Created by jimmyt on 8/6/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation

/**
 Validates settlement methods belonging to the user of this interface.
 
 This function ensures that:
    - the user has selected at least one settlement method
    - the user has specified a price for each selected settlement method
    - the user has supplied their information for each selected settlement method.
    - the information that the user has supplied for each settlement method is valid.
    - the type of information that the user has supplied for each settlement method corresponds to that type of settlement method.
 
 - Parameter settlementMethods: The `Array` of `SettlementMethod`s to be validated.
 
 - Returns: An `Array` of validated `SettlementMethod`s
 
 - Throws An `SettlementMethodValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateSettlementMethods(
    _ settlementMethods: [SettlementMethod]
) throws -> [SettlementMethod] {
    guard !settlementMethods.isEmpty else {
        throw SettlementMethodValidationError(desc: "You must specify at least one settlement method.")
    }
    try settlementMethods.forEach { settlementMethod in
        guard settlementMethod.price != "" else {
            throw SettlementMethodValidationError(desc: "You must specify a price for each settlement method you select.")
        }
        guard let privateData = settlementMethod.privateData else {
            throw SettlementMethodValidationError(desc: "You must supply your information for each settlement method you select.")
        }
        guard let privateDataStruct = createPrivateDataStruct(privateData: privateData.data(using: .utf8) ?? Data()) else {
            throw SettlementMethodValidationError(desc: "Your \(settlementMethod.currency) \(settlementMethod.method) has invalid details")
        }
        if privateDataStruct is PrivateSEPAData {
            if settlementMethod.method != "SEPA" {
                throw SettlementMethodValidationError(desc: "You cannot not supply SEPA details for a \(settlementMethod.method) settlement method.")
            }
        } else if privateDataStruct is PrivateSWIFTData {
            if settlementMethod.method != "SWIFT" {
                throw SettlementMethodValidationError(desc: "You cannot not supply SWIFT details for a \(settlementMethod.method) settlement method.")
            }
        } else {
            throw SettlementMethodValidationError(desc: "You must select a supported settlement method")
        }
    }
    return settlementMethods
}

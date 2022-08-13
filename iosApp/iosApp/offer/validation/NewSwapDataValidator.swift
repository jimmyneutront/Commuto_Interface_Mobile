//
//  NewSwapDataValidator.swift
//  iosApp
//
//  Created by jimmyt on 8/11/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt

/**
 Validates the data that the user has specified while attempting to take an offer, so that the offer taking transaction does not revert.
 
 This function ensures that:
    - the isUserMaker field is false (meaning the user is not the maker of the offer)
    - the havePublicKey field is true (meaning this interface has a copy of the maker's public key)
    - (if the offer's lower and upper bound amounts are not equal) the takenSwapAmount is within the bounds specified by the offer maker
    - the user has selected a settlement method
    - the settlement method selected by the user is accepted by the offer maker
 
 - Parameters:
    - offer: The `Offer` that is being taken.
    - takenSwapAmount: (If the lower and upper bound amounts of `offer` are equal, this will not be used.) The stablecoin amount that the user wants to buy/sell as a `Decimal`
    - selectedSettlementMethod: The settlement method by which the user wants to send/receive payment to/from the maker.
    - stablecoinInformationRepository: The `StablecoinInformationRepository` that this will use to convert `takenSwapAmount` to ERC20 base units.
 
 - Returns: A `ValidatedNewSwapData` derived from the inputs to this function.
 
 - Throws: A `NewSwapDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateNewSwapData(
    offer: Offer,
    takenSwapAmount: Decimal,
    selectedSettlementMethod: SettlementMethod?,
    stablecoinInformationRepository: StablecoinInformationRepository
) throws -> ValidatedNewSwapData {
    guard !offer.isUserMaker else {
        throw NewSwapDataValidationError(desc: "You cannot take your own offer.")
    }
    guard offer.havePublicKey else {
        throw NewSwapDataValidationError(desc: "The maker's public key has not yet been obtained.")
    }
    guard let stablecoinInformation = stablecoinInformationRepository.getStablecoinInformation(chainID: offer.chainID, contractAddress: offer.stablecoin) else {
        throw NewSwapDataValidationError(desc: "Could not validate stablecoin contract address.")
    }
    let takenSwapAmountBaseUnits: BigUInt = try {
        if (offer.amountLowerBound == offer.amountUpperBound) {
            return offer.amountLowerBound
        } else {
            return try stablecoinAmountToBaseUnits(amount: takenSwapAmount, stablecoinInformation: stablecoinInformation)
        }
    }()
    guard offer.amountLowerBound <= takenSwapAmountBaseUnits else {
        throw NewSwapDataValidationError(desc: "You must specify a stablecoin amount that is not less than the minimum amount.")
    }
    guard offer.amountUpperBound >= takenSwapAmountBaseUnits else {
        throw NewSwapDataValidationError(desc: "You must specify a stablecoin amount that is not greater than the maximum amount.")
    }
    guard let selectedSettlementMethod = selectedSettlementMethod else {
        throw NewSwapDataValidationError(desc: ".")
    }
    guard let selectedSettlementMethodInArray = offer.settlementMethods.first(where: { settlementMethod in
        settlementMethod.currency == selectedSettlementMethod.currency && settlementMethod.price == selectedSettlementMethod.price && settlementMethod.method == selectedSettlementMethod.method
    }) else {
        throw NewSwapDataValidationError(desc: "The user does not use the settlement method you selected.")
    }
    return ValidatedNewSwapData(takenSwapAmount: takenSwapAmountBaseUnits, settlementMethod: selectedSettlementMethodInArray)
}

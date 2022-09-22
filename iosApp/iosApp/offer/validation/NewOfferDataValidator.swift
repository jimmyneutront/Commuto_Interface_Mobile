//
//  NewOfferDataValidator.swift
//  iosApp
//
//  Created by jimmyt on 7/22/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Validates the data that the user has specified for the creation of a new offer, so that the offer creation transaction does not revert.
 
 This function ensures that:
 - the user has selected a valid stablecoin
 - the minimum stablecoin amount is greater than zero
 - the maximum stablecoin amount is greater than or equal to the minimum amount
 - the security deposit amount is at least 10% of the maximum stablecoin amount
 - the minimum service fee amount is greater than zero
 - the user has specified a valid direction
 - the user has selected at least one settlement method
 - the user has specified a price for each selected settlement method.
 - the user has supplied their information for each selected settlement method.
 
- Parameters:
    - chainID: The ID of the blockchain on which the offer should be created.
    - stablecoin: The contract address of the stablecoin selected by the user, or `nil` if the user has not selected a stablecoin.
    - stablecoinInformation: The `StablecoinInformation` for the stablecoin selected by the user, or `nil` if the user has not selected a stablecoin.
    - minimumAmount: The minimum stablecoin amount to be exchanged, as specified by the user.
    - maximumAmount: The maximum stablecoin amount to be exchanged, as specified by the user.
    - securityDepositAmount: The security deposit amount, as specified by the user.
    - serviceFeeRate: The current [service fee rate](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-whitepaper.txt).
    - direction: The exchange direction indicated by the user, either `buy` or `sell`.
    - settlementMethods: The `SettlementMethod`s selected by the user.
 
 - Returns: A `ValidatedNewOfferData` derived from the inputs to this function.
 
 - Throws: A `NewOfferDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateNewOfferData(
    chainID: BigUInt,
    stablecoin: EthereumAddress?,
    stablecoinInformation: StablecoinInformation?,
    minimumAmount: Decimal,
    maximumAmount: Decimal,
    securityDepositAmount: Decimal,
    serviceFeeRate: BigUInt,
    direction: OfferDirection,
    settlementMethods: [SettlementMethod]
) throws -> ValidatedNewOfferData {
    guard stablecoin != nil && stablecoinInformation != nil else {
        throw NewOfferDataValidationError(desc: "You must select a valid stablecoin.")
    }
    let minimumAmountBaseUnits = try stablecoinAmountToBaseUnits(amount: minimumAmount, stablecoinInformation: stablecoinInformation!)
    guard minimumAmountBaseUnits > BigUInt.zero else {
        throw NewOfferDataValidationError(desc: "Minimum amount must be greater than zero.")
    }
    let maximumAmountBaseUnits = try stablecoinAmountToBaseUnits(amount: maximumAmount, stablecoinInformation: stablecoinInformation!)
    guard maximumAmountBaseUnits >= minimumAmountBaseUnits else {
        throw NewOfferDataValidationError(desc: "Maximum amount must not be less than the minimum amount.")
    }
    let securityDepositAmountBaseUnits = try stablecoinAmountToBaseUnits(amount: securityDepositAmount, stablecoinInformation: stablecoinInformation!)
    guard securityDepositAmountBaseUnits * BigUInt(10) >= maximumAmountBaseUnits else {
        throw NewOfferDataValidationError(desc: "The security deposit amount must be at least 10% of the maximum amount.")
    }
    let serviceFeeAmountLowerBound = serviceFeeRate * (minimumAmountBaseUnits / BigUInt(10_000))
    guard serviceFeeAmountLowerBound > BigUInt.zero || serviceFeeRate == BigUInt.zero else {
        throw NewOfferDataValidationError(desc: "The minimum service fee amount must be greater than zero.")
    }
    let serviceFeeRateUpperBound = serviceFeeRate * (maximumAmountBaseUnits / BigUInt(10_000))
    guard !settlementMethods.isEmpty else {
        throw NewOfferDataValidationError(desc: "You must specify at least one settlement method.")
    }
    try settlementMethods.forEach { settlementMethod in
        guard settlementMethod.price != "" else {
            throw NewOfferDataValidationError(desc: "You must specify a price for each settlement method you select.")
        }
        guard settlementMethod.privateData != nil else {
            throw NewOfferDataValidationError(desc: "You must supply your information for each settlement method you select.")
        }
    }
    return ValidatedNewOfferData(
        stablecoin: stablecoin!,
        stablecoinInformation: stablecoinInformation!,
        minimumAmount: minimumAmountBaseUnits,
        maximumAmount: maximumAmountBaseUnits,
        securityDepositAmount: securityDepositAmountBaseUnits,
        serviceFeeRate: serviceFeeRate,
        serviceFeeAmountLowerBound: serviceFeeAmountLowerBound,
        serviceFeeAmountUpperBound: serviceFeeRateUpperBound,
        direction: direction,
        settlementMethods: settlementMethods
    )
}

/**
 Converts a stablecoin amount as a `Decimal` to a base unit amount as a `BigUInt`, according to the decimal value of `stablecoinInformation`. So for example, consider USDC with a decimal value of 6: `Decimal(1)` USDC becomes `BigUInt("1_000_000")` USDC in base units.

 It would be nice to multiply the amount `Decimal` by ten raised to the power of the stablecoin's decimal value, convert the result to an `Int`, and then convert that Int to a `BigUInt`. However, stablecoin's decimal values can be large, which would result in an overflow error when converting the `Decimal` to an `Int`. The following is an example of what NOT to do:
 
 ```
 let amountBaseUnits = BigUInt(NSDecimalNumber(decimal: amount * pow(Decimal(10), stablecoinInformation.decimal)).rounding(accordingToBehavior: roundingHandler).intValue)
 ```
 
 Instead, we ensure the amount has no more than six decimal places, and then convert its significand to an `Int` by rounding up and then a `BigUInt`. This should be safe, since the significand should have zero decimal places itself. Then, recalling that `minimumAmount.exponent` will be negative whenever `amount` has numbers on the trialing side of the decimal point, we calculate `intermediateUnitsAmountExponent = stablecoinInformation.decimal + minimumAmount.exponent`.  If `intermediateUnitsAmountExponent` is positive, we multiply the `BigUInt` amount by `BigUInt(10).pow(intermediateUnitsAmountExponent)` If `intermediateUnitsAmountExponent` is negative, we divide the `BigUInt` amount by `BigUInt(10).pow(-intermediateUnitsAmountExponent)`. Note that the result will be truncated to an integer, not rounded.  This gives us our resulting amount in stablecoin base units, and allows us to handle the case in which the stablecoin's decimal value is less than the number of decimal places in `amount`.
 
 
 Examples:
 
 Consider the amount 1.234 for a stablecoin with a decimal value of 2:
 - amount exponent = -3
 - amount in intermediate units = 1234
 - intermediate units exponent = 2 + -3 = -1
 The intermediate units exponent is negative, so we return: `1234 / 10.pow(-(-1)) = 123` (recalling that the division is truncated.)
 
 Consider the amount 1.234 for a stablecoin with a decimal value of 6:
 -  amount exponent = -3
 - amount in intermediate units = 1234
 - intermediate units exponent = 6 + -3 = 3
 The intermediate units exponent is positive, so we return `1234 * 10.pow(3) = 1_234_000`.
 
 - Parameters:
    - amount: The `Decimal` amount to be converted to base units.
    - stablecoinInformation: The `StablecoinInformation` from which this gets the decimal value to use when converting `amount`.
 
 - Returns `amount` in token base units as a `BigUInt`.
 
 - Throws: An `OfferServiceError.newOfferDataValidationError` if `amount` is not positive, or if `amount`'s exponent value is greater than six.
 */
func stablecoinAmountToBaseUnits(amount: Decimal, stablecoinInformation: StablecoinInformation) throws -> BigUInt {
    let roundingHandler = NSDecimalNumberHandler(roundingMode: NSDecimalNumber.RoundingMode.up, scale: 0, raiseOnExactness: true, raiseOnOverflow: true, raiseOnUnderflow: true, raiseOnDivideByZero: true)
    guard amount > Decimal.zero else {
        throw NewOfferDataValidationError(desc: "Stablecoin amount must be positive.")
    }
    guard amount.exponent >= -6 else {
        throw NewOfferDataValidationError(desc: "Stablecoin amount must have no more than six decimal places.")
    }
    let amountIntermediateUnits = BigUInt(NSDecimalNumber(decimal: amount.significand).rounding(accordingToBehavior: roundingHandler).intValue)
    let intermediateUnitsAmountExponent = stablecoinInformation.decimal + amount.exponent
    if intermediateUnitsAmountExponent >= 0 {
        let amountBaseUnits = amountIntermediateUnits * BigUInt(10).power(intermediateUnitsAmountExponent)
        return amountBaseUnits
    } else {
        // Note: The result of this division will be truncated, not rounded.
        let amountBaseUnits = amountIntermediateUnits / BigUInt(10).power(-intermediateUnitsAmountExponent)
        return amountBaseUnits
    }
}

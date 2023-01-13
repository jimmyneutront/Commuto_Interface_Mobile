//
//  FillSwapValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/12/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) can be called for `swap`.
 
 This function ensures that:
    - [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) is not already being called for `swap`.
    - The user of this interface is the maker and seller of `swap`.
    - The next step in the swapping process for `swap` is the user calling [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)
 
 - Parameter swap: The `Swap` to be validated.

 - Throws: A `SwapDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateSwapForFilling(swap: Swap) throws {
    guard swap.fillingSwapState == .none || swap.fillingSwapState == .validating || swap.fillingSwapState == .error else {
        throw SwapDataValidationError(desc: "This Swap is already being filled.")
    }
    guard swap.role == .makerAndSeller else {
        throw SwapDataValidationError(desc: "Only Maker-As-Seller Swaps can be filled")
    }
    guard swap.state == .awaitingFilling else {
        throw SwapDataValidationError(desc: "This Swap cannot currently be filled")
    }
}

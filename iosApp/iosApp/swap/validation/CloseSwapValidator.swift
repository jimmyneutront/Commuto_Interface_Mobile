//
//  CloseSwapValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) can be called for `swap`.
 
 This function ensures that :
    - [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) is not already being called for `swap`.
    - the next step in the swapping process for `swap` is the user calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent).
 
 - Parameter swap: The `Swap` to be validated.
 
 - Throws: A `SwapDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateSwapForClosing(swap: Swap) throws {
    guard (swap.closingSwapState == .none || swap.closingSwapState == .validating || swap.closingSwapState == .error) else {
        throw SwapDataValidationError(desc: "This Swap is already being closed.")
    }
    guard swap.state == .awaitingClosing else {
        throw SwapDataValidationError(desc: "This Swap cannot currently be closed.")
    }
}

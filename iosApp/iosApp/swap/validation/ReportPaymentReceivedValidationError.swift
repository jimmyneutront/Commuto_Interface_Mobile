//
//  ReportPaymentReceivedValidationError.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) can be called for `swap`.
 
 This function ensures that:
    -  [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) is not already being called for `swap`.
    - the user is the seller for `swap`.
    - the next step in the swapping process for `swap` is the user calling [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received).
 
 - Parameter swap: The `Swap` to be validated.
 
 - Throws: A `SwapDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateSwapForReportingPaymentReceived(swap: Swap) throws {
    guard (swap.reportingPaymentReceivedState == .none || swap.reportingPaymentReceivedState == .validating || swap.reportingPaymentReceivedState == .error) else {
        throw SwapDataValidationError(desc: "Payment receiving is already being reported this swap.")
    }
    guard swap.role == .makerAndSeller || swap.role == .takerAndSeller else {
        throw SwapDataValidationError(desc: "Only the Seller can report receiving payment")
    }
    guard swap.state == .awaitingPaymentReceived else {
        throw SwapDataValidationError(desc: "Payment receiving cannot currently be reported for this swap.")
    }
}

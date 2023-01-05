//
//  ReportPaymentSentValidator.swift
//  iosApp
//
//  Created by jimmyt on 1/4/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Ensures that [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) can be called for `swap`.
 
 This function ensures that:
    - [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) is not already being called for `swap`.
    - the user is the buyer for `swap`.
    - the next step in the swapping process for `swap` is the user calling [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent)
 
 - Parameter swap: The `Swap` to be validated.
 
 - Throws: A `SwapDataValidationError` if this is not able to ensure any of the conditions in the list above. The descriptions of the errors thrown by this function are human-readable and can be displayed to the user so that they can correct any problems.
 */
func validateSwapForReportingPaymentSent(swap: Swap) throws {
    guard (swap.reportingPaymentSentState == .none || swap.reportingPaymentSentState == .validating || swap.reportingPaymentSentState == .error) else {
        throw SwapDataValidationError(desc: "Payment sending is already being reported this swap.")
    }
    guard swap.role == .makerAndBuyer || swap.role == .takerAndBuyer else {
        throw SwapDataValidationError(desc: "Only the Buyer can report sending payment")
    }
    guard swap.state == .awaitingPaymentSent else {
        throw SwapDataValidationError(desc: "Payment sending cannot currently be reported for this swap.")
    }
}

//
//  ReportingPaymentSentState.swift
//  iosApp
//
//  Created by jimmyt on 9/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Indicates whether we are currently reporting that payment has been sent for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap). If we are, then this indicates the part of the payment reporting process we are currently in.
 */
enum ReportingPaymentSentState {
    /**
     Indicates that we are not currently reporting that payment is sent for the corresponding swap.
     */
    case none
    /**
     Indicates that we are currently checking if we can report that payment is sent for the swap.
     */
    case checking
    /**
     Indicates that we are currently calling CommutoSwap's [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) function for the swap.
     */
    case reporting
    /**
     Indicates that we have reported that payment is sent for the corresponding swap.
     */
    case completed
    /**
     Indicates that we encountered an error while reporting that payment is sent for the corresponding swap.
     */
    case error
    
    /**
     A human readable string describing the current state.
     */
    var description: String {
        switch self {
        case .none: // Note: This should not be used.
            return "Press Report Payment Sent to report that you have sent payment"
        case .checking:
            return "Checking that payment sending can be reported..."
        case .reporting:
            return "Reporting that payment is sent..."
        case .completed:
            return "Successfully reported that payment is sent."
        case .error:
            return "An error occurred." // Note: This should not be used; instead, the actual error message should be displayed.
        }
    }
}

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
    case none
    case checking
    case reporting
    case completed
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

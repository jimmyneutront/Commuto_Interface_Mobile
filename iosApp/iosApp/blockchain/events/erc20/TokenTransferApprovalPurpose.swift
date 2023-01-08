//
//  TokenTransferApprovalPurpose.swift
//  iosApp
//
//  Created by jimmyt on 1/6/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Describes the purpose for which a token transfer allowance was set, such as opening an offer or filling a swap.
 */
enum TokenTransferApprovalPurpose {
    /**
     Indicates that the corresponding token transfer allowance was set in order to open an offer.
     */
    case openOffer
    
    /**
     A human-readable string describing an instance of this type.
     */
    var asString: String {
        switch self {
        case .openOffer:
            return "openOffer"
        }
    }
    
}

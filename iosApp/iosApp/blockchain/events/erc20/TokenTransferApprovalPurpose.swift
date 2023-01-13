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
     Indicates that the corresponding token transfer allowance was set in order to take an offer.
     */
    case takeOffer
    /**
     Indicates that the corresponding token transfer allowance was set in order to fill a maker-as-seller swap.
     */
    case fillSwap
    
    /**
     A human-readable string describing an instance of this type.
     */
    var asString: String {
        switch self {
        case .openOffer:
            return "openOffer"
        case .takeOffer:
            return "takeOffer"
        case .fillSwap:
            return "fillSwap"
        }
    }
    
}

//
//  BlockchainTransactionType.swift
//  iosApp
//
//  Created by jimmyt on 12/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes what a particular transaction wrapped by a particular`BlockchainTransaction` does. (For example: opens a new offer, fills a swap, etc.)
 */
enum BlockchainTransactionType {
    /**
     Indicates that a `BlockchainTransaction` cancels an open [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    case cancelOffer
    /**
     Indicates that a `BlockchainTransaction` edits an open [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    case editOffer
    
    /**
     A human-readable string describing an instance of this type.
     */
    var asString: String {
        switch self {
        case .cancelOffer:
            return "cancelOffer"
        case .editOffer:
            return "editOffer"
        }
    }
    
}

//
//  OfferDirection.swift
//  iosApp
//
//  Created by jimmyt on 7/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes the direction of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer), which specifies whether the maker wants to buy or sell stablecoin.
 */
enum OfferDirection {
    /**
     Indicates that the maker wants to buy stablecoin.
     */
    case buy
    /**
     Indicates that the maker wants to sell stablecoin.
     */
    case sell
    
    /**
     The direction in human readable format.
     */
    var string: String {
        switch self {
        case.buy:
            return "Buy"
        case .sell:
            return "Sell"
        }
    }
}

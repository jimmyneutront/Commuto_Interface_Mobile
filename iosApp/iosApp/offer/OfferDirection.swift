//
//  OfferDirection.swift
//  iosApp
//
//  Created by jimmyt on 7/7/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt

/**
 Describes the direction of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer), which specifies whether the maker wants to buy or sell stablecoin.
 */
enum OfferDirection: CaseIterable, Identifiable {
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
        case .buy:
            return "Buy"
        case .sell:
            return "Sell"
        }
    }
    
    /**
     The direction in the form stored on chain, as a `BigUInt` literal.
     */
    var onChainValue: BigUInt {
        switch self {
        case .buy:
            return BigUInt(0)
        case .sell:
            return BigUInt(1)
        }
    }
    
    /**
     An identity for an instance of this enum, required for adoption of `Identifiable` protocol
     */
    var id: Self { self }
    
}

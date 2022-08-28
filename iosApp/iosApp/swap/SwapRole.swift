//
//  SwapRole.swift
//  iosApp
//
//  Created by jimmyt on 8/27/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes the role of the user of this interface for a particular `Swap`.
 */
enum SwapRole {
    /**
     Indicates that the user of this interface was the maker of the corresponding swap, and offered to buy stablecoin.
     */
    case makerAndBuyer
    /**
     Indicates that the user of this interface was the maker of the corresponding swap, and offered to sell stablecoin.
     */
    case makerAndSeller
    /**
     Indicates that the user of this interface was the taker of the corresponding swap, and is buying stablecoin (meaning that the taken offer was a sell offer).
     */
    case takerAndBuyer
    /**
     Indicates that the user of this interface was the taker of the corresponding swap, and is selling stablecoin (meaning that the taken offer was a buy offer).
     */
    case takerAndSeller
    
    /**
     Returns a `String` corresponding to a particular case of `SwapRole`.
     */
    var asString: String {
        switch self {
        case .makerAndBuyer:
            return "makerAndBuyer"
        case .makerAndSeller:
            return "makerAndSeller"
        case .takerAndBuyer:
            return "takerAndBuyer"
        case .takerAndSeller:
            return "takerAndSeller"
        }
    }
    
    /**
     Attempts to create a `SwapRole` corresponding to the given `String`, or returns `nil` if no case corresponds to the given `String`.
     
     - Parameter string: The `String` from which this attempts to create a corresponding `SwapRole`
     
     - Returns: A `SwapRole` corresponding to `string`, or `nil` if no such `SwapRole` exists.
     */
    static func fromString(_ string: String?) -> SwapRole? {
        if string == nil {
            return nil
        } else if string == "makerAndBuyer" {
            return .makerAndBuyer
        } else if string == "makerAndSeller" {
            return .makerAndSeller
        } else if string == "takerAndBuyer" {
            return .takerAndBuyer
        } else if string == "takerAndSeller" {
            return .takerAndSeller
        } else {
            return nil
        }
    }
    
}

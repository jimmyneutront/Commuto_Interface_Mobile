//
//  SwapState.swift
//  iosApp
//
//  Created by jimmyt on 8/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes the state of a `Swap` according to the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt). The order in which the cases of this `enum` are defined is the order in which a swap should move through the states that they represent.
 */
enum SwapState {
    /**
     Indicates that [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer) has not yet been called for the offer corresponding to the associated swap.
     */
    case taking
    /**
     Indicates that the transaction to take the offer corresponding to the associated swap has been broadcast.
     */
    case takeOfferTransactionBroadcast
    /**
     Indicates that the swap has been taken on-chain, and now the swap taker must announce their settlement method information and public key.
     */
    case awaitingTakerInformation
    /**
     Indicates that the taker has announced their settlement method information and public key. and now the swap maker must announce their settlement method information.
     */
    case awaitingMakerInformation
    
    /**
     Returns a `String` corresponding to a particular case of `SwapState`.
     */
    var asString: String {
        switch self {
        case .taking:
            return "taking"
        case .takeOfferTransactionBroadcast:
            return "takeOfferTxBrdcst"
        case .awaitingTakerInformation:
            return "awaitingTakerInfo"
        case .awaitingMakerInformation:
            return "awaitingMakerInfo"
        }
    }
    
    /**
     Attempts to create a `SwapState` corresponding to the given `String`, or returns `nil` if no case corresponds to the given `String`.
     
     - Parameter string: The `String` from which this attempts to create a corresponding `SwapState
     
     - Returns: A `SwapState` corresponding to `string`, or `nil` if no such `SwapState` exists.
     */
    static func fromString(_ string: String?) -> SwapState? {
        if string == nil {
            return nil
        } else if string == "taking" {
            return .taking
        } else if string == "takeOfferTxBrdcst" {
            return .takeOfferTransactionBroadcast
        } else if string  == "awaitingTakerInfo" {
            return .awaitingTakerInformation
        } else if string == "awaitingMakerInfo" {
            return .awaitingMakerInformation
        } else {
            return nil
        }
    }
}

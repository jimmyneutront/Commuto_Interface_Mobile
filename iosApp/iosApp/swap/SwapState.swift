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
     Indicates that the swap has been taken on-chain, and now the swap taker must send their settlement method information and public key to the maker.
     */
    case awaitingTakerInformation
    /**
     Indicates that the taker has sent their settlement method information and public key to the maker, and now the swap maker must send their settlement method information to the taker.
     */
    case awaitingMakerInformation
    /**
     Indicates that the maker has sent their settlement method information to the taker, and that the swap is a maker-as-seller swap and the maker must now fill the swap. If the swap is a maker-as-buyer swap, this is not used.
     */
    case awaitingFilling
    /**
     Indicates that the swap is a maker-as-seller swap and that the transaction to fill the swap has been broadcast.
     */
    case fillSwapTransactionBroadcast
    /**
     If the swap is a maker-as-seller swap, this indicates that the maker has filled the swap, and the buyer must now send payment for the stablecoin they are purchasing. If the swap is a maker-as-buyer swap, this indicates that the maker has sent their settlement method information to the taker, and the buyer must now send payment for the stablecoin they are purchasing.
     */
    case awaitingPaymentSent
    /**
     This indicates that the buyer's transaction to report that they have sent payment has been broadcast.
     */
    case reportPaymentSentTransactionBroadcast
    /**
     This indicates that the seller must confirm that they have received fiat currency payment from the buyer.
     */
    case awaitingPaymentReceived
    /**
     This indicates that the seller's transaction to report that they have received payment has been broadcast.
     */
    case reportPaymentReceivedTransactionBroadcast
    /**
     This indicates that the seller has reported receipt of fiat payment from the buyer, and the swap can now be closed.
     */
    case awaitingClosing
    
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
        case .awaitingFilling:
            return "awaitingFilling"
        case .fillSwapTransactionBroadcast:
            return "fillSwapTransactionBroadcast"
        case .awaitingPaymentSent:
            return "awaitingPaymentSent"
        case .reportPaymentSentTransactionBroadcast:
            return "reportPaymentSentTransactionBroadcast"
        case .awaitingPaymentReceived:
            return "awaitingPaymentReceived"
        case .reportPaymentReceivedTransactionBroadcast:
            return "reportPaymentReceivedTransactionBroadcast"
        case .awaitingClosing:
            return "awaitingClosing"
        }
    }
    
    /**
     Attempts to create a `SwapState` corresponding to the given `String`, or returns `nil` if no case corresponds to the given `String`.
     
     - Parameter string: The `String` from which this attempts to create a corresponding `SwapState`
     
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
        } else if string == "awaitingFilling" {
            return .awaitingFilling
        } else if string == "fillSwapTransactionBroadcast" {
            return .fillSwapTransactionBroadcast
        } else if string == "awaitingPaymentSent" {
            return .awaitingPaymentSent
        } else if string == "reportPaymentSentTransactionBroadcast" {
            return .reportPaymentSentTransactionBroadcast
        } else if string == "awaitingPaymentReceived" {
            return .awaitingPaymentReceived
        } else if string == "reportPaymentReceivedTransactionBroadcast" {
            return .reportPaymentReceivedTransactionBroadcast
        } else if string == "awaitingClosing" {
            return .awaitingClosing
        } else {
            return nil
        }
    }
}

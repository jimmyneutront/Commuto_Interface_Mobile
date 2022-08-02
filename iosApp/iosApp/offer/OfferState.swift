//
//  OfferState.swift
//  iosApp
//
//  Created by jimmyt on 7/28/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes the state of an `Offer` according to the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt). The order in which the cases of this `enum` are defined is the order in which an offer should move through the states that they represent.
 */
enum OfferState {
    /**
     Indicates that [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) has not yet been called for the corresponding offer.
     */
    case opening
    /**
     Indicates that the transaction to open the corresponding offer has been broadcast.
     */
    case openOfferTransactionBroadcast
    /**
     Indicates that the [OfferOpened event](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) for the corresponding offer has been detected, so, if the offer's maker is the user of the interface, the public key should now be announced; otherwise this means that we are waiting for the maker to announce their public key.
     */
    case awaitingPublicKeyAnnouncement
    /**
     Indicates that the corresponding offer has been opened on chain and the maker's public key has been announced.
     */
    case offerOpened
    
    /**
     Returns an `Int` corresponding to this state's position in a list of possible offer states organized according to the order in which an offer should move through them, with the earliest state at the beginning (corresponding to the integer 0) and the latest state at the end (corresponding to the integer 3).
     */
    var indexNumber: Int {
        switch self {
        case .opening:
            return 0
        case .openOfferTransactionBroadcast:
            return 1
        case .awaitingPublicKeyAnnouncement:
            return 2
        case .offerOpened:
            return 3
        }
    }
    
    /**
     Returns a `String` corresponding to a particular case of `OfferState`.
     */
    var asString: String {
        switch self {
        case .opening:
            return "opening"
        case .openOfferTransactionBroadcast:
            return "openOfferTxPublished"
        case .awaitingPublicKeyAnnouncement:
            return "awaitingPKAnnouncement"
        case .offerOpened:
            return "offerOpened"
        }
    }
    
    /**
     Attempts to create an `OfferState` corresponding to the given `String`, or returns `nil` if no case corresponds to the given `String`.
     
     - Parameter string: The `String` from which this attempts to create a corresponding `OfferState`.
     
     - Returns An `OfferState` corresponding to `string`, or `nil` if no such `OfferState` exists.
     */
    static func fromString(_ string: String?) -> OfferState? {
        if string == nil {
            return nil
        } else if string == "opening" {
            return .opening
        } else if string == "openOfferTxPublished" {
            return .openOfferTransactionBroadcast
        } else if string == "awaitingPKAnnouncement" {
            return .awaitingPublicKeyAnnouncement
        } else if string == "offerOpened" {
            return .offerOpened
        } else {
            return nil
        }
    }
    
}

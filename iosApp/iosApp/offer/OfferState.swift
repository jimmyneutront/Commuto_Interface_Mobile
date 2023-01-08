//
//  OfferState.swift
//  iosApp
//
//  Created by jimmyt on 7/28/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Describes the state of an `Offer` according to the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt). The order in which the non-cancellation-related cases of this `enum` are defined is the order in which an offer should move through the states that they represent. The order in which the cancellation-related cases are defined is the order in which an offer being canceled should move through the states that they represent.
 */
enum OfferState {
    /**
     Indicates that the transaction that attempted to call [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to open the corresponding offer has failed, and a new one has not yet been created.
     */
    case transferApprovalFailed
    /**
     Indicates that this is currently calling [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to open the corresponding offer.
     */
    case approvingTransfer
    /**
     Indicates that the transaction that calls [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) for the corresponding offer has been sent to a connected blockchain node.
     */
    case approveTransferTransactionSent
    /**
     Indicates that the transaction that calls [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to approve a token transfer to allow opening the corresponding offer has been confirmed, and the user must now open the offer.
     */
    case awaitingOpening
    /**
     Indicates that the transaction to call [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) for the corresponding offer has been sent to a connected blockchain node.
     */
    case openOfferTransactionSent
    /**
     Indicates that the [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) event for the corresponding offer has been detected, so, if the offer's maker is the user of the interface, the public key should now be announced; otherwise this means that we are waiting for the maker to announce their public key.
     */
    case awaitingPublicKeyAnnouncement
    /**
     Indicates that the corresponding offer has been opened on chain and the maker's public key has been announced.
     */
    case offerOpened
    /**
     Indicates that the corresponding offer has been taken.
     */
    case taken
    
    /**
     Indicates that the corresponding offer has been canceled on chain.
     */
    case canceled
    
    
    /**
     Returns an `Int` corresponding to this state's position in a list of possible offer states organized according to the order in which an offer should move through them, with the earliest state at the beginning (corresponding to the integer 0), the latest state at the end (corresponding to the integer 3), and cancellation-related states corresponding to -1.
     */
    var indexNumber: Int {
        switch self {
        case .transferApprovalFailed:
            return 0
        case .approvingTransfer:
            return 1
        case .approveTransferTransactionSent:
            return 2
        case .awaitingOpening:
            return 3
        case .openOfferTransactionSent:
            return 4
        case .awaitingPublicKeyAnnouncement:
            return 5
        case .offerOpened:
            return 6
        case .taken:
            return 7
        case .canceled:
            return -1
        }
    }
    
    /**
     Returns a `String` corresponding to a particular case of `OfferState`.
     */
    var asString: String {
        switch self {
        case .transferApprovalFailed:
            return "transferApprovalFailed"
        case .approvingTransfer:
            return "approvingTransfer"
        case .approveTransferTransactionSent:
            return "approveTransferTransactionSent"
        case .awaitingOpening:
            return "awaitingOpening"
        case .openOfferTransactionSent:
            return "openOfferTransactionSent"
        case .awaitingPublicKeyAnnouncement:
            return "awaitingPKAnnouncement"
        case .offerOpened:
            return "offerOpened"
        case .taken:
            return "taken"
        case .canceled:
            return "canceled"
        }
    }
    
    /**
     Attempts to create an `OfferState` corresponding to the given `String`, or returns `nil` if no case corresponds to the given `String`.
     
     - Parameter string: The `String` from which this attempts to create a corresponding `OfferState`.
     
     - Returns: An `OfferState` corresponding to `string`, or `nil` if no such `OfferState` exists.
     */
    static func fromString(_ string: String?) -> OfferState? {
        if string == nil {
            return nil
        } else if string == "transferApprovalFailed" {
            return .transferApprovalFailed
        } else if string == "approvingTransfer" {
            return .approvingTransfer
        } else if string == "approveTransferTransactionSent" {
            return .approveTransferTransactionSent
        } else if string == "awaitingOpening" {
            return .awaitingOpening
        } else if string == "openOfferTransactionSent" {
            return .openOfferTransactionSent
        } else if string == "awaitingPKAnnouncement" {
            return .awaitingPublicKeyAnnouncement
        } else if string == "offerOpened" {
            return .offerOpened
        } else if string == "taken" {
            return .taken
        } else if string == "canceled" {
            return .canceled
        } else {
            return nil
        }
    }
    
}

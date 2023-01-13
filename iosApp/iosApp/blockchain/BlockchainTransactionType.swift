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
     Indicates that a `BlockchainTransaction` approves a token transfer by calling [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to open an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)
     */
    case approveTokenTransferToOpenOffer
    /**
     Indicates that a `BlockchainTransaction` opens an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) by calling [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer)
     */
    case openOffer
    /**
     Indicates that a `BlockchainTransaction` cancels an open [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    case cancelOffer
    /**
     Indicates that a `BlockchainTransaction` edits an open [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    case editOffer
    /**
     Indicates that a `BlockchainTransaction` approves a token transfer by calling [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to take an open [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    case approveTokenTransferToTakeOffer
    /**
     Indicates that a `BlockchainTransaction` takes an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) by calling [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer).
     */
    case takeOffer
    /**
     Indicates that a `BlockchainTransaction` approves a token transfer by calling [approve](https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-) in order to fill a maker as seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) made by the user of this interface.
     */
    case approveTokenTransferToFillSwap
    /**
     Indicates that a `BlockchainTransaction` fills a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) made by the user of this interface by calling [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap).
     */
    case fillSwap
    /**
     Indicates that a `BlockchainTransaction` reports that payment has been sent for a swap by calling [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent)
     */
    case reportPaymentSent
    /**
     Indicates that a `BlockchainTransaction` reports that payment has been received for a swap by calling [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received)
     */
    case reportPaymentReceived
    /**
     Indicates that a `BlockchainTransaction` closes a swap by calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap)
     */
    case closeSwap
    
    /**
     A human-readable string describing an instance of this type.
     */
    var asString: String {
        switch self {
        case .approveTokenTransferToOpenOffer:
            return "approveTokenTransferToOpenOffer"
        case .openOffer:
            return "openOffer"
        case .cancelOffer:
            return "cancelOffer"
        case .editOffer:
            return "editOffer"
        case .approveTokenTransferToTakeOffer:
            return "approveTokenTransferToTakeOffer"
        case .takeOffer:
            return "takeOffer"
        case .approveTokenTransferToFillSwap:
            return "approveTokenTransferToFillSwap"
        case .fillSwap:
            return "fillSwap"
        case .reportPaymentSent:
            return "reportPaymentSent"
        case .reportPaymentReceived:
            return "reportPaymentReceived"
        case .closeSwap:
            return "closeSwap"
        }
    }
    
}

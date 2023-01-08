//
//  TokenTransferApprovalState.swift
//  iosApp
//
//  Created by jimmyt on 1/5/23.
//  Copyright © 2023 orgName. All rights reserved.
//

/**
 Indicates whether we are currently approving the transfer of an [ERC20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) token. If we are, then this indicates the part of the transfer approval process we are currently in.
 */
enum TokenTransferApprovalState {
    /**
     Indicates that we are NOT currently approving a token transfer.
     */
    case none
    /**
     Indicates that we are currently checking whether a token transfer can be approved.
     */
    case validating
    /**
     Indicates that we are currently sending the transaction that will approve a token transfer.
     */
    case sendingTransaction
    /**
     Indicates that we have sent the transaction that will approve a token transfer, and we are waiting for it to be confirmed.
     */
    case awaitingTransactionConfirmation
    /**
     Indicates that we have approved a token transfer, and the transaction that did so has been confirmed.
     */
    case completed
    /**
     Indicates that we encountered an error while approving a token transfer.
     */
    case error
    
    /**
     Returns a `String` corresponding to a particular case of `TokenTransferApprovalState`.
     */
    var asString: String {
        switch self {
        case .none:
            return "none"
        case .validating:
            return "validating"
        case .sendingTransaction:
            return "sendingTransaction"
        case .awaitingTransactionConfirmation:
            return "awaitingTransactionConfirmation"
        case .completed:
            return "completed"
        case .error:
            return "error"
        }
    }
    
}

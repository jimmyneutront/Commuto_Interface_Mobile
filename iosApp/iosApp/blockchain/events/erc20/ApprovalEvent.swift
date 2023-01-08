//
//  ApprovalEvent.swift
//  iosApp
//
//  Created by jimmyt on 1/5/23.
//  Copyright © 2023 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 This represents an [Approval](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) event emitted by an ERC20 contract.
 */
struct ApprovalEvent {
    /**
     The address of the token owner for which the allowance was set.
     */
    let owner: EthereumAddress
    /**
     The address of the contract that has been given permission to spend some of `owner`'s balance.
     */
    let spender: EthereumAddress
    /**
     The amount of `owner`'s balance that `spender` is allowed to spend.
     */
    let amount: BigUInt
    /**
     The reason for creating an allowance, such as opening an offer, or filling a swap.
     */
    let purpose: TokenTransferApprovalPurpose
    /**
     The hash of the transaction that emitted this event.
     */
    let transactionHash: String
    /**
     The ID of the blockchain on which this event was emitted
     */
    let chainID: BigUInt
    
    /**
     Creates a new `ApprovalEvent` given a web3swift `EventParserResultProtocol` containing information from an [Approval](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) event, or returns `nil` if the passed `EventParserResultProtocol` doesn't contain information from an Approval event.
     
     - Parameters:
        - result: A web3swift `EventParserResultProtocol`, from which this attempts to create an `ApprovalEvent`.
        - purpose: A `TokenTransferApprovalPurpose` describing why the corresponding allowance was approved, such as to open an offer or fill a swap.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init?(_ result: EventParserResultProtocol, purpose: TokenTransferApprovalPurpose, chainID: BigUInt) {
        guard let owner = result.decodedResult["_owner"] as? EthereumAddress else {
            return nil
        }
        guard let spender = result.decodedResult["_spender"] as? EthereumAddress else {
            return nil
        }
        guard let amount = result.decodedResult["_value"] as? BigUInt else {
            return nil
        }
        guard let eventLog = result.eventLog else {
            return nil
        }
        var transactionHash = eventLog.transactionHash.toHexString().lowercased()
        if !transactionHash.hasPrefix("0x") {
            transactionHash = "0x\(transactionHash)"
        }
        self.transactionHash = transactionHash
        self.owner = owner
        self.spender = spender
        self.amount = amount
        self.purpose = purpose
        self.chainID = chainID
    }
    
    /**
     Creates a new `ApprovalEvent`.
     
     - Parameters:
        - owner: The address of the token holder, for which a transfer allowance has been set.
        - spender: The address that is allowed to spend some of `owner`'s balance.
        - amount: The amount of `owner`'s balance that `spender` is allowed to spend.
        - purpose: A `TokenTransferApprovalPurpose` describing why the corresponding allowance was approved, such as to open an offer or fill a swap.
        - transactionHash: The hash of the transaction that emitted this event.
        - chainID: The ID of the blockchain on which this event was emitted.
     */
    init(owner: EthereumAddress, spender: EthereumAddress, amount: BigUInt, purpose: TokenTransferApprovalPurpose, transactionHash: String, chainID: BigUInt) {
        self.owner = owner
        self.spender = spender
        self.amount = amount
        self.purpose = purpose
        self.transactionHash = transactionHash
        self.chainID = chainID
    }
    
}

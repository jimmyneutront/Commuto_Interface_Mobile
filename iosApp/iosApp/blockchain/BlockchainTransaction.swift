//
//  BlockchainTransaction.swift
//  iosApp
//
//  Created by jimmyt on 12/3/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import web3swift

/**
 A wrapper around an optional `EthereumTransaction` that was created by this interface and should be monitored by this interface for confirmation, transaction dropping, transaction failure and transaction success. The `transaction` property of an instance of this struct may be `nil` if this `BlockchainTransaction` represents a transaction that was created before a restart of the application. In this case, only the hash of such a transaction is saved in persistent storage, and so this struct will have been re-created using that hash in persistent storage, not the `EthereumTransaction` itself. This also contains the date and time at which the original transaction was created, as well as the latest block number of the blockchain at the time when the original transaction was created.
 */
struct BlockchainTransaction {
    /**
     The `EthereumTransaction` that this wraps.
     */
    let transaction: EthereumTransaction?
    /**
     The hash of `transaction`, or if `transaction` is `nil`, the hash of the transaction that this struct represents.
     */
    let transactionHash: String
    /**
     The date and time at which this was created.
     */
    let timeOfCreation: Date
    /**
     The number of the latest block in the blockchain at the time when this transaction was created.
     */
    let latestBlockNumberAtCreation: UInt64
    /**
     Describes what `transaction` does. (For example: one that opens a new offer, one that fills a swap, etc).
     */
    let type: BlockchainTransactionType
    
    /**
     Creates a `BlockchainTransaction` wrapped around an `EthereumTransaction` of a specified `BlockchainTransactionType`, created when the number of the newest block on the blockchain was `latestBlockNumberAtCreation`, and throws an error if the hash of the `EthereumTransaction` cannot be calculated.
     
     - Parameters:
        - transaction: The `EthereumTransaction` that this wraps.
        - latestBlockNumberAtCreation The number of the newest block on the blockchain at the time when `transaction` was created.
        - type: A `BlockchainTransactionType` indicating what `transaction` will do when/if it is confirmed.
     
     - Throws: A `BlockchainTransactionError` if the hash of `transaction` cannot be determined.
     */
    init(transaction: EthereumTransaction, latestBlockNumberAtCreation: UInt64, type: BlockchainTransactionType) throws {
        guard let transactionHashWithoutHexPrefix = transaction.hash?.toHexString().lowercased() else {
            throw BlockchainTransactionError(errorDescription: "Unable to get hash for transaction")
        }
        var transactionHash = transactionHashWithoutHexPrefix
        if !transactionHash.hasPrefix("0x") {
            transactionHash = "0x" + transactionHash
        }
        self.transactionHash = transactionHash
        self.transaction = transaction
        self.timeOfCreation = Date()
        self.latestBlockNumberAtCreation = latestBlockNumberAtCreation
        self.type = type
    }
    
    /**
     Creates a `BlockchainTransaction` with a `nil` `BlockchainTransaction.transaction` property, with a hash equal to `transactionHash`,  which identifies an `EthereumTransaction` created at `timeOfCreation`, when the latest block had block number `latestBlockNumberAtCreation`, and is of type `type`.
     
     - Parameters:
        - transactionHash: The hash of the `EthereumTransaction` that this represents.
        - timeOfCreation: The time at which the `EthereumTransaction` that this represents was created.
        - type: A `BlockchainTransactionType` indicating what the corresponding `EthereumTransaction` will do/has done when/if it will be/is confirmed.
     */
    init(transactionHash: String, timeOfCreation: Date, latestBlockNumberAtCreation: UInt64, type: BlockchainTransactionType) {
        self.transaction = nil
        self.transactionHash = transactionHash
        self.timeOfCreation = timeOfCreation
        self.latestBlockNumberAtCreation = latestBlockNumberAtCreation
        self.type = type
    }
    
}

/**
 An error thrown by `BlockchainTransaction`-related code.
 */
struct BlockchainTransactionError: LocalizedError {
    /**
     A description providing information about the context in which the error was thrown.
     */
    public var errorDescription: String?
}

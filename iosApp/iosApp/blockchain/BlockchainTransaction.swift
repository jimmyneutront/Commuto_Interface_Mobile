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
 A wrapper around an `EthereumTransaction` that was created by this interface and should be monitored by this interface for confirmation, transaction dropping, transaction failure and transaction success. This also contains the date and time at which this transaction was created, as well as the latest block number of the blockchain at the time when this transaction was created.
 */
struct BlockchainTransaction {
    /**
     The `EthereumTransaction` that this wraps.
     */
    let transaction: EthereumTransaction
    /**
     The date and time at which this was created.
     */
    let timeOfCreation: Date = Date()
    /**
     The number of the latest block in the blockchain at the time when this transaction was created.
     */
    let latestBlockNumberAtCreation: UInt64
    /**
     Describes what `transaction` does. (For example: one that opens a new offer, one that fills a swap, etc).
     */
    let type: BlockchainTransactionType
    
}

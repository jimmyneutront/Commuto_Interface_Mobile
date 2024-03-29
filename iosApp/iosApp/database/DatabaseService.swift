//
//  DatabaseService.swift
//  iosApp
//
//  Created by jimmyt on 11/27/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import os
import SQLite

/**
 The Database Service Class.
 
 This is responsible for storing data, serving it to other services upon request, and accepting services' requests to add and remove data from storage.
 */
class DatabaseService {
    
    /**
     Creates a new `DatabaseService`, and creates an in-memory database with its reference stored in `DatabaseService`'s `connection` property.
     
     - Parameter databaseKey: The `SymmetricKey` with which this will encrypt and decrypt encrypted database fields. If no value is provided, this uses the key created by `DatabaseKeyDeriver` given the password "test\_password" and salt string "test\_salt". Note that the default value should ONLY be used for testing/development.
     */
    init(
        databaseKey: SymmetricKey = try! DatabaseKeyDeriver(password: "test_password", salt: "test_salt".data(using: .utf8)!).key
    ) throws {
        connection = try Connection(.inMemory)
        self.databaseKey = databaseKey
    }
    
    /**
     DatabaseService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "DatabaseService")
    
    /**
     The connection to the SQLite database.
     */
    var connection: Connection
    
    /**
     The `SymmetricKey` with which this encrypts and decrypts encrypted database fields.
     */
    let databaseKey: SymmetricKey
    
    /**
     The serial DispatchQueue used to synchronize database access. All database queries should be run on this queue to prevent data races.
     */
    let databaseQueue = DispatchQueue(label: "databaseService.serial.queue")
    
    /**
     A database table of `Offer`s.
     */
    let offers = Table("Offer")
    /**
     A database table of settlement methods (each of which corresponds to a specific offer) and their encrypted private data and corresponding initialization vectors, as Base-64 `String` encoded  bytes.
     */
    let offerSettlementMethods = Table("OfferSettlementMethod")
    /**
     A database table of settlement methods (in exactly the same format as those in `offerSettlementMethods`) that will become the actual settlement methods of an offer once an [EditOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer) transaction is confirmed.
     */
    let pendingOfferSettlementMethods = Table("PendingOfferSettlementMethod")
    /**
     A database table of `KeyPair`s.
     */
    let keyPairs = Table("KeyPair")
    /**
     A database table of `PublicKey`s.
     */
    let publicKeys = Table("PublicKey")
    /**
     A database table of `Swap`s.
     */
    let swaps = Table("Swap")
    /**
     A database table containing the user's settlement methods and their encrypted private data and corresponding initialization vectors, as Base-64 `String` encoded bytes.
     */
    let userSettlementMethods = Table("UserSettlementMethod")
    
    /**
     A database structure representing an offer or swap ID.
     */
    let id = Expression<String>("id")
    /**
     A database structure representing an interface ID.
     */
    let interfaceId = Expression<String>("interfaceId")
    /**
     A database structure representing a public key.
     */
    let publicKey = Expression<String>("publicKey")
    /**
     A database structure representing a private key.
     */
    let privateKey = Expression<String>("privateKey")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `isCreated` property.
     */
    let isCreated = Expression<Bool>("isCreated")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `isTaken` property.
     */
    let isTaken = Expression<Bool>("isTaken")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `requiresFill` property.
     */
    let requiresFill = Expression<Bool>("requiresFill")
    /**
     A database structure representing the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     */
    let maker = Expression<String>("maker")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `makerInterfaceID` property,
     */
    let makerInterfaceID = Expression<String>("makerInterfaceID")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `taker` property.
     */
    let taker = Expression<String>("taker")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `takerInterfaceID` property.
     */
    let takerInterfaceID = Expression<String>("takerInterfaceID")
    /**
     A database structure representing a stablecoin smart contract address.
     */
    let stablecoin = Expression<String>("stablecoin")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `amountLowerBound` property.
     */
    let amountLowerBound = Expression<String>("amountLowerBound")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `amountUpperBound` property.
     */
    let amountUpperBound = Expression<String>("amountUpperBound")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `securityDepositAmount` property.
     */
    let securityDepositAmount = Expression<String>("securityDepositAmount")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `takenSwapAmount` property.
     */
    let takenSwapAmount = Expression<String>("takenSwapAmount")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `serviceFeeAmount` property.
     */
    let serviceFeeAmount = Expression<String>("serviceFeeAmount")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `serviceFeeRate` property.
     */
    let serviceFeeRate = Expression<String>("serviceFeeRate")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `direction` property.
     */
    let onChainDirection = Expression<String>("onChainDirection")
    /**
     A database structure representing a particular settlement method of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     */
    let settlementMethod = Expression<String>("settlementMethod")
    /**
     A database structure representing encrypted private data for a particular settlement method of an offer. This field is optional because this interface may not have private data for settlement methods not owned by the user.
     */
    let privateSettlementMethodData = Expression<String?>("privateData")
    /**
     A database structure representing an initialization vector used to encrypt a piece of private settlement method data corresponding to a settlement method of an offer. This field is optional because this interface may not have private data (and thus no initialization vector) for settlement methods not owned by the user.
     */
    let privateSettlementMethodDataInitializationVector = Expression<String?>("privateDataInitializationVector")
    /**
     A database structure representing a maker's encrypted private data for their swap's settlement method. This field is optional because this interface may not yet have obtained the swap maker's private data.
     */
    let makerPrivateSettlementMethodData = Expression<String?>("makerPrivateData")
    /**
     A database structure representing an initialization vector used to encrypt a `makerPrivateSettlementMethodData`. This field is optional because this interface may not have   `makerPrivateSettlementMethodData`.
     */
    let makerPrivateSettlementMethodDataInitializationVector = Expression<String?>("makerPrivateDataInitializationVector")
    /**
     A database structure representing a taker's encrypted private data for their swap's settlement method. This field is optional because this interface may not yet have obtained the swap taker's private data.
     */
    let takerPrivateSettlementMethodData = Expression<String?>("takerPrivateData")
    /**
     A database structure representing an initialization vector used to encrypt a `takerPrivateSettlementMethodData`. This field is optional because this interface may not have   `takerPrivateSettlementMethodData`.
     */
    let takerPrivateSettlementMethodDataInitializationVector = Expression<String?>("takerPrivateDataInitializationVector")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)  or [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `protocolVersion` property.
     */
    let protocolVersion = Expression<String>("protocolVersion")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `isPaymentSent` property.
     */
    let isPaymentSent = Expression<Bool>("isPaymentSent")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `isPaymentReceived` property.
     */
    let isPaymentReceived = Expression<Bool>("isPaymentReceived")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `hasBuyerClosed` property.
     */
    let hasBuyerClosed = Expression<Bool>("hasBuyerClosed")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `hasSellerClosed` property.
     */
    let hasSellerClosed = Expression<Bool>("hasSellerClosed")
    /**
     A database structure representing a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap)'s `disputeRaiser` property.
     */
    let disputeRaiser = Expression<String>("disputeRaiser")
    /**
     A database structure representing a blockchain ID.
     */
    let chainID = Expression<String>("chainID")
    /**
     A database structure  representing an `Offer`'s `havePublicKey` property.
     */
    let havePublicKey = Expression<Bool>("havePublicKey")
    /**
     A database structure representing an `Offer`'s `isUserMaker` property.
     */
    let isUserMaker = Expression<Bool>("isUserMaker")
    /**
     A database structure representing an `Offer`'s `state` property.
     */
    let offerState = Expression<String>("state")
    /**
     A database structure representing an `Offer`'s `approveToOpenState` property.
     */
    let approveToOpenState = Expression<String>("approveToOpenState")
    /**
     A database structure representing the hash of a transaction that approved a token transfer allowance in order to open an `Offer` made by the user of this interface.
     */
    let approveToOpenTransactionHash = Expression<String?>("approveToOpenTransactionHash")
    /**
     A database structure representing the creation time of a transaction that approved a token transfer allowance in order to open an `Offer` made by the user of this interface.
     */
    let approveToOpenTransactionCreationTime = Expression<String?>("approveToOpenTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that approved a token transfer allowance in order to open an `Offer` made by the user of this interface.
     */
    let approveToOpenTransactionCreationBlockNumber = Expression<Int?>("approveToOpenTransactionCreationBlockNumber")
    /**
     A database structure representing an `Offer`'s `openingOfferState` property.
     */
    let openingOfferState = Expression<String>("openingOfferState")
    /**
     A database structure representing the hash of a transaction that opened an `Offer` made by the user of this interface.
     */
    let openingOfferTransactionHash = Expression<String?>("openingOfferTransactionHash")
    /**
     A database structure representing the creation time of a transaction that opened an `Offer` made by the user of this interface.
     */
    let openingOfferTransactionCreationTime = Expression<String?>("openingOfferTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that opened an `Offer` made by the user of this interface.
     */
    let openingOfferTransactionCreationBlockNumber = Expression<Int?>("openingOfferTransactionCreationBlockNumber")
    /**
     A database structure representing an `Offer`'s `cancelingOfferState` property.
     */
    let cancelingOfferState = Expression<String>("cancelingOfferState")
    /**
     A database structure representing the hash of a transaction that canceled an `Offer` made by the user of this interface.
     */
    let offerCancellationTransactionHash = Expression<String?>("offerCancellationTransactionHash")
    /**
     A database structure representing the creation time of a transaction that canceled an `Offer` made by the user of this interface.
     */
    let offerCancellationTransactionCreationTime = Expression<String?>("offerCancellationTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that canceled an `Offer` made by the user of this interface.
     */
    let offerCancellationTransactionCreationBlockNumber = Expression<Int?>("offerCancellationTransactionCreationBlockNumber")
    /**
     A database structure representing an `Offer`'s `editingOfferState` property.
     */
    let editingOfferState = Expression<String>("editingOfferState")
    /**
     A database structure representing the hash of a transaction that edited an `Offer` made by the user of this interface.
     */
    let offerEditingTransactionHash = Expression<String?>("offerEditingTransactionHash")
    /**
     A database structure representing the creation time of a transaction that edited an `Offer` made by the user of this interface.
     */
    let offerEditingTransactionCreationTime = Expression<String?>("offerEditingTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that edited an `Offer` made by the user of this interface.
     */
    let offerEditingTransactionCreationBlockNumber = Expression<Int?>("offerEditingTransactionCreationBlockNumber")
    /**
     A database structure representing an `Offer`'s `approveToTakeState` property.
     */
    let approveToTakeState = Expression<String>("approveToTakeState")
    /**
     A database structure representing the hash of a transaction that approved a token transfer allowance in order to take an `Offer` NOT made by the user of this interface.
     */
    let approveToTakeTransactionHash = Expression<String?>("approveToTakeTransactionHash")
    /**
     A database structure representing the creation time of a transaction that approved a token transfer allowance in order to take an `Offer` NOT made by the user of this interface.
     */
    let approveToTakeTransactionCreationTime = Expression<String?>("approveToTakeTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that approved a token transfer allowance in order to take an `Offer` NOT made by the user of this interface.
     */
    let approveToTakeTransactionCreationBlockNumber = Expression<Int?>("approveToTakeTransactionCreationBlockNumber")
    /**
     A database structure representing an `Offer`'s `takingOfferState` property.
     */
    let takingOfferState = Expression<String>("takingOfferState")
    /**
     A database structure representing the hash of a transaction that opened an `Offer` taken by the user of this interface.
     */
    let takingOfferTransactionHash = Expression<String?>("takingOfferTransactionHash")
    /**
     A database structure representing the creation time of a transaction that took an `Offer` taken by the user of this interface.
     */
    let takingOfferTransactionCreationTime = Expression<String?>("takingOfferTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that took an `Offer` taken by the user of this interface.
     */
    let takingOfferTransactionCreationBlockNumber = Expression<Int?>("takingOfferTransactionCreationBlockNumber")
    /**
     A database structure representing a `Swaps`'s `state` property.
     */
    let swapState = Expression<String>("state")
    /**
     A database structure representing a `Swap`'s `role` property.
     */
    let swapRole = Expression<String>("role")
    /**
     A database structure representing a `Swap`'s `approveToFillState` property.
     */
    let approveToFillState = Expression<String>("approveToFillState")
    /**
     A database structure representing the hash of a transaction that called [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) for a maker-as-seller swap involving the user of this interface. This will be `nil` for swaps that are not maker-as-seller.
     */
    let approveToFillTransactionHash = Expression<String?>("approveToFillTransactionHash")
    /**
     A database structure representing the creation time of a transaction that called [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) for a maker-as-seller swap involving user of this interface. This may not be accurate for swaps in which the user is the taker/buyer, and will be `nil` for swaps that are not maker-as-seller.
     */
    let approveToFillTransactionCreationTime = Expression<String?>("approveToFillTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that called [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) for a maker-as-seller swap involving user of this interface. This may not be accurate for swaps in which the user is the seller, and will be `nil` for swaps that are not maker-as-seller.
     */
    let approveToFillTransactionCreationBlockNumber = Expression<Int?>("approveToFillTransactionCreationBlockNumber")
    /**
     A database structure representing a `Swap`'s `fillingSwapState` property.
     */
    let fillingSwapState = Expression<String>("fillingSwapState")
    /**
     A database structure representing the hash of a transaction that filled a maker-as-seller `Swap`.
     */
    let fillingSwapTransactionHash = Expression<String?>("fillingSwapTransactionHash")
    /**
     A database structure representing the creation time of a transaction that filled a maker-as-seller `Swap`.
     */
    let fillingSwapTransactionCreationTime = Expression<String?>("fillingSwapTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that filled a maker-as-seller `Swap`.
     */
    let fillingSwapTransactionCreationBlockNumber = Expression<Int?>("fillingSwapTransactionCreationBlockNumber")
    /**
     A database structure representing a `Swap`'s `reportPaymentSentState` property.
     */
    let reportPaymentSentState = Expression<String>("reportPaymentSentState")
    /**
     A database structure representing the hash of a transaction that called [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a swap involving user of this interface.
     */
    let reportPaymentSentTransactionHash = Expression<String?>("reportPaymentSentTransactionHash")
    /**
     A database structure representing the creation time of a transaction that called [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a swap involving user of this interface. This may not be accurate for swaps in which the user is the seller.
     */
    let reportPaymentSentTransactionCreationTime = Expression<String?>("reportPaymentSentTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that called [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a swap involving user of this interface. This may not be accurate for swaps in which the user is the seller.
     */
    let reportPaymentSentTransactionCreationBlockNumber = Expression<Int?>("reportPaymentSentTransactionCreationBlockNumber")
    /**
     A database structure representing a `Swap`'s `reportPaymentReceivedState` property.
     */
    let reportPaymentReceivedState = Expression<String>("reportPaymentReceivedState")
    /**
     A database structure representing the hash of a transaction that called [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a swap involving user of this interface.
     */
    let reportPaymentReceivedTransactionHash = Expression<String?>("reportPaymentReceivedTransactionHash")
    /**
     A database structure representing the creation time of a transaction that called [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a swap involving user of this interface. This may not be accurate for swaps in which the user is the buyer.
     */
    let reportPaymentReceivedTransactionCreationTime = Expression<String?>("reportPaymentReceivedTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of a transaction that called [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a swap involving user of this interface. This may not be accurate for swaps in which the user is the buyer.
     */
    let reportPaymentReceivedTransactionCreationBlockNumber = Expression<Int?>("reportPaymentReceivedTransactionCreationBlockNumber")
    /**
     A database structure representing a `Swap`'s `closeSwapState` property.
     */
    let closeSwapState = Expression<String>("closeSwapState")
    /**
     A database structure representing the hash of the transaction (signed by the user of this interface) that called [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a swap involving user of this interface.
     */
    let closeSwapTransactionHash = Expression<String?>("closeSwapTransactionHash")
    /**
     A database structure representing the creation time of the transaction (signed by the user of this interface) that called [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a swap involving user of this interface.
     */
    let closeSwapTransactionCreationTime = Expression<String?>("closeSwapTransactionCreationTime")
    /**
     A database structure representing the latest block number at creation time of the transaction (signed by the user of this interface) that called [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a swap involving user of this interface.
     */
    let closeSwapTransactionCreationBlockNumber = Expression<Int?>("closeSwapTransactionCreationBlockNumber")
    
    /**
     A database structure representing the ID of a settlement method, as a Type 4 UUID string.
     */
    let settlementMethodID = Expression<String>("settlementMethodID")
    
    /**
     Creates all necessary database tables.
     */
    func createTables() throws {
        try connection.run(offers.create { t in
            t.column(id, unique: true)
            t.column(isCreated)
            t.column(isTaken)
            t.column(maker)
            t.column(interfaceId)
            t.column(stablecoin)
            t.column(amountLowerBound)
            t.column(amountUpperBound)
            t.column(securityDepositAmount)
            t.column(serviceFeeRate)
            t.column(onChainDirection)
            t.column(protocolVersion)
            t.column(chainID)
            t.column(havePublicKey)
            t.column(isUserMaker)
            t.column(offerState)
            t.column(approveToOpenState)
            t.column(approveToOpenTransactionHash)
            t.column(approveToOpenTransactionCreationTime)
            t.column(approveToOpenTransactionCreationBlockNumber)
            t.column(openingOfferState)
            t.column(openingOfferTransactionHash)
            t.column(openingOfferTransactionCreationTime)
            t.column(openingOfferTransactionCreationBlockNumber)
            t.column(cancelingOfferState)
            t.column(offerCancellationTransactionHash)
            t.column(offerCancellationTransactionCreationTime)
            t.column(offerCancellationTransactionCreationBlockNumber)
            t.column(editingOfferState)
            t.column(offerEditingTransactionHash)
            t.column(offerEditingTransactionCreationTime)
            t.column(offerEditingTransactionCreationBlockNumber)
            t.column(approveToTakeState)
            t.column(approveToTakeTransactionHash)
            t.column(approveToTakeTransactionCreationTime)
            t.column(approveToTakeTransactionCreationBlockNumber)
            t.column(takingOfferState)
            t.column(takingOfferTransactionHash)
            t.column(takingOfferTransactionCreationTime)
            t.column(takingOfferTransactionCreationBlockNumber)
        })
        try connection.run(offerSettlementMethods.create { t in
            t.column(id)
            t.column(chainID)
            t.column(settlementMethod)
            t.column(privateSettlementMethodData)
            t.column(privateSettlementMethodDataInitializationVector)
        })
        try connection.run(pendingOfferSettlementMethods.create { t in
            t.column(id)
            t.column(chainID)
            t.column(settlementMethod)
            t.column(privateSettlementMethodData)
            t.column(privateSettlementMethodDataInitializationVector)
        })
        try connection.run(keyPairs.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
            t.column(privateKey)
        })
        try connection.run(publicKeys.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
        })
        try connection.run(swaps.create { t in
            t.column(id, unique: true)
            t.column(isCreated)
            t.column(requiresFill)
            t.column(maker)
            t.column(makerInterfaceID)
            t.column(taker)
            t.column(takerInterfaceID)
            t.column(stablecoin)
            t.column(amountLowerBound)
            t.column(amountUpperBound)
            t.column(securityDepositAmount)
            t.column(takenSwapAmount)
            t.column(serviceFeeAmount)
            t.column(serviceFeeRate)
            t.column(onChainDirection)
            t.column(settlementMethod)
            t.column(makerPrivateSettlementMethodData)
            t.column(makerPrivateSettlementMethodDataInitializationVector)
            t.column(takerPrivateSettlementMethodData)
            t.column(takerPrivateSettlementMethodDataInitializationVector)
            t.column(protocolVersion)
            t.column(isPaymentSent)
            t.column(isPaymentReceived)
            t.column(hasBuyerClosed)
            t.column(hasSellerClosed)
            t.column(disputeRaiser)
            t.column(chainID)
            t.column(swapState)
            t.column(swapRole)
            t.column(approveToFillState)
            t.column(approveToFillTransactionHash)
            t.column(approveToFillTransactionCreationTime)
            t.column(approveToFillTransactionCreationBlockNumber)
            t.column(fillingSwapState)
            t.column(fillingSwapTransactionHash)
            t.column(fillingSwapTransactionCreationTime)
            t.column(fillingSwapTransactionCreationBlockNumber)
            t.column(reportPaymentSentState)
            t.column(reportPaymentSentTransactionHash)
            t.column(reportPaymentSentTransactionCreationTime)
            t.column(reportPaymentSentTransactionCreationBlockNumber)
            t.column(reportPaymentReceivedState)
            t.column(reportPaymentReceivedTransactionHash)
            t.column(reportPaymentReceivedTransactionCreationTime)
            t.column(reportPaymentReceivedTransactionCreationBlockNumber)
            t.column(closeSwapState)
            t.column(closeSwapTransactionHash)
            t.column(closeSwapTransactionCreationTime)
            t.column(closeSwapTransactionCreationBlockNumber)
        })
        try connection.run(userSettlementMethods.create { t in
            t.column(settlementMethodID, unique: true)
            t.column(settlementMethod)
            t.column(privateSettlementMethodData)
            t.column(privateSettlementMethodDataInitializationVector)
        })
    }
    
    /**
     Persistently stores a `DatabaseOffer`. If a `DatabaseOffer` with an offer ID equal to that of `offer` already exists in the database, this does nothing.
     
     - Parameter offer: The `offer` to be persistently stored.
     */
    func storeOffer(offer: DatabaseOffer) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(offers.insert(
                    id <- offer.id,
                    isCreated <- offer.isCreated,
                    isTaken <- offer.isTaken,
                    maker <- offer.maker,
                    interfaceId <- offer.interfaceId,
                    stablecoin <- offer.stablecoin,
                    amountLowerBound <- offer.amountLowerBound,
                    amountUpperBound <- offer.amountUpperBound,
                    securityDepositAmount <- offer.securityDepositAmount,
                    serviceFeeRate <- offer.serviceFeeRate,
                    onChainDirection <- offer.onChainDirection,
                    protocolVersion <- offer.protocolVersion,
                    chainID <- offer.chainID,
                    havePublicKey <- offer.havePublicKey,
                    isUserMaker <- offer.isUserMaker,
                    offerState <- offer.state,
                    approveToOpenState <- offer.approveToOpenState,
                    approveToOpenTransactionHash <- offer.approveToOpenTransactionHash,
                    approveToOpenTransactionCreationTime <- offer.approveToOpenTransactionCreationTime,
                    approveToOpenTransactionCreationBlockNumber <- offer.approveToOpenTransactionCreationBlockNumber,
                    openingOfferState <- offer.openingOfferState,
                    openingOfferTransactionHash <- offer.openingOfferTransactionHash,
                    openingOfferTransactionCreationTime <- offer.openingOfferTransactionCreationTime,
                    openingOfferTransactionCreationBlockNumber <- offer.openingOfferTransactionCreationBlockNumber,
                    cancelingOfferState <- offer.cancelingOfferState,
                    offerCancellationTransactionHash <- offer.offerCancellationTransactionHash,
                    offerCancellationTransactionCreationTime <- offer.offerCancellationTransactionCreationTime,
                    offerCancellationTransactionCreationBlockNumber <- offer.offerCancellationTransactionCreationBlockNumber,
                    editingOfferState <- offer.editingOfferState,
                    offerEditingTransactionHash <- offer.offerEditingTransactionHash,
                    offerEditingTransactionCreationTime <- offer.offerEditingTransactionCreationTime,
                    offerEditingTransactionCreationBlockNumber <- offer.offerEditingTransactionCreationBlockNumber,
                    approveToTakeState <- offer.approveToTakeState,
                    approveToTakeTransactionHash <- offer.approveToTakeTransactionHash,
                    approveToTakeTransactionCreationTime <- offer.approveToTakeTransactionCreationTime,
                    approveToTakeTransactionCreationBlockNumber <- offer.approveToTakeTransactionCreationBlockNumber,
                    takingOfferState <- offer.takingOfferState,
                    takingOfferTransactionHash <- offer.takingOfferTransactionHash,
                    takingOfferTransactionCreationTime <- offer.takingOfferTransactionCreationTime,
                    takingOfferTransactionCreationBlockNumber <- offer.takingOfferTransactionCreationBlockNumber
                ))
                logger.notice("storeOffer: stored offer with B64 ID \(offer.id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: Offer.id" {
                // An Offer with the specified ID already exists in the database, so we do nothing
                logger.notice("storeOffer: offer with B64 ID \(offer.id) already exists in database")
            }
        }
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `havePublicKey` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - havePublicKey: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `havePublicKey` field.
     */
    func updateOfferHavePublicKey(offerID: String, _chainID: String, _havePublicKey: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(havePublicKey <- _havePublicKey))
        }
        logger.notice("updateOfferHavePublicKey: set value to \(_havePublicKey) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `state` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `state` field.
     */
    func updateOfferState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(offerState <- state))
        }
        logger.notice("updateOfferState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `approveToOpenState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToOpenState` field.
     */
    func updateOfferApproveToOpenState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(approveToOpenState <- state))
        }
        logger.notice("updateOfferApproveToOpenState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `approveToOpenTransactionHash`, `approveToOpenTransactionCreationTime`, and `approveToOpenTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToOpenTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToOpenTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToOpenTransactionCreationBlockNumber` field.
     */
    func updateOfferApproveToOpenData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    approveToOpenTransactionHash <- transactionHash,
                    approveToOpenTransactionCreationTime <- transactionCreationTime,
                    approveToOpenTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOfferApproveToOpenData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `openingOfferState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `openingOfferState` field.
     */
    func updateOpeningOfferState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(openingOfferState <- state))
        }
        logger.notice("updateOpeningOfferState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `openingOfferTransactionHash`, `openingOfferTransactionCreationTime`, and `openingOfferTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `openingOfferTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `openingOfferTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `openingOfferTransactionCreationBlockNumber` field.
     */
    func updateOpeningOfferData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    openingOfferTransactionHash <- transactionHash,
                    openingOfferTransactionCreationTime <- transactionCreationTime,
                    openingOfferTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOpeningOfferData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `cancelingOfferState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `cancelingOfferState` field.
     */
    func updateCancelingOfferState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(cancelingOfferState <- state))
        }
        logger.notice("updateCancelingOfferState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `offerCancellationTransactionHash`, `offerCancellationTransactionCreationTime`, and `offerCancellationTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerCancellationTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerCancellationTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerCancellationTransactionCreationBlockNumber` field.
     */
    func updateOfferCancellationData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    offerCancellationTransactionHash <- transactionHash,
                    offerCancellationTransactionCreationTime <- transactionCreationTime,
                    offerCancellationTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOfferCancellationData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `editingOfferState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `editingOfferState` field.
     */
    func updateEditingOfferState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(editingOfferState <- state))
        }
        logger.notice("updateEditingOfferState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `offerEditingTransactionHash`, `offerEditingTransactionCreationTime`, and `offerEditingTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerEditingTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerEditingTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `offerEditingTransactionCreationBlockNumber` field.
     */
    func updateOfferEditingData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    offerEditingTransactionHash <- transactionHash,
                    offerEditingTransactionCreationTime <- transactionCreationTime,
                    offerEditingTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOfferEditingData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `approveToTakeState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToTakeState` field.
     */
    func updateOfferApproveToTakeState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(approveToTakeState <- state))
        }
        logger.notice("updateOfferApproveToTakeState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `approveToTakeTransactionHash`, `approveToTakeTransactionCreationTime`, and `approveToTakeTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToTakeTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToTakeTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `approveToTakeTransactionCreationBlockNumber` field.
     */
    func updateOfferApproveToTakeData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    approveToTakeTransactionHash <- transactionHash,
                    approveToTakeTransactionCreationTime <- transactionCreationTime,
                    approveToTakeTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOfferApproveToTakeData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `takingOfferState` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `takingOfferState` field.
     */
    func updateTakingOfferState(offerID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).update(takingOfferState <- state))
        }
        logger.notice("updateTakingOfferState: set value to \(state) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `takingOfferTransactionHash`, `takingOfferTransactionCreationTime`, and `takingOfferTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `takingOfferTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `takingOfferTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `takingOfferTransactionCreationBlockNumber` field.
     */
    func updateTakingOfferData(offerID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID)
                .update(
                    takingOfferTransactionHash <- transactionHash,
                    takingOfferTransactionCreationTime <- transactionCreationTime,
                    takingOfferTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateTakingOfferData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Removes every `DatabaseOffer` with an offer ID equal to `offerID` and a chain ID equal to `chainID` from persistent storage.
     
     - Parameters:
        - offerID: The ID of the offers to be removed, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offers to be removed, as a `String`.
     */
    func deleteOffers(offerID: String, _chainID: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(id == offerID && chainID == _chainID).delete())
        }
        logger.notice("deleteOffers: deleted offers with B64 ID \(offerID) and chain ID \(_chainID), if present")
    }
    
    /**
     Retrieves the persistently stored `DatabaseOffer` with the specified offer ID, or returns `nil` if no such event is present.
     
     - Parameter id: The offer ID of the `DatabaseOffer` to return, as a Base64-`String` of bytes.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is `nil`, and a `DatabaseServiceError.unexpectedQueryResult` if multiple `DatabaseOffer`s are found with the same offer ID or if the offer ID of the `DatabaseOffer` returned from the database does not match `id`.
     
     - Returns: A `DatabaseOffer` corresponding to `id`, or `nil` if no such `DatabaseOffer` is found.
     */
    func getOffer(id _id: String) throws -> DatabaseOffer? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(offers.filter(id == _id))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getOffer call")
        }
        let result = try Array(rowIterator!)
        if result.count > 1 {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple Offers found with given offer id \(id)")
        } else if result.count == 1 {
            guard result[0][id] == _id else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Offer ID of returned Offer did not match specified offer ID " + _id)
            }
            logger.notice("getOffer: returning offer with B64 ID \(_id)")
            return DatabaseOffer(
                id: result[0][id],
                isCreated: result[0][isCreated],
                isTaken: result[0][isTaken],
                maker: result[0][maker],
                interfaceId: result[0][interfaceId],
                stablecoin: result[0][stablecoin],
                amountLowerBound: result[0][amountLowerBound],
                amountUpperBound: result[0][amountUpperBound],
                securityDepositAmount: result[0][securityDepositAmount],
                serviceFeeRate: result[0][serviceFeeRate],
                onChainDirection: result[0][onChainDirection],
                protocolVersion: result[0][protocolVersion],
                chainID: result[0][chainID],
                havePublicKey: result[0][havePublicKey],
                isUserMaker: result[0][isUserMaker],
                state: result[0][offerState],
                approveToOpenState: result[0][approveToOpenState],
                approveToOpenTransactionHash: result[0][approveToOpenTransactionHash],
                approveToOpenTransactionCreationTime: result[0][approveToOpenTransactionCreationTime],
                approveToOpenTransactionCreationBlockNumber: result[0][approveToOpenTransactionCreationBlockNumber],
                openingOfferState: result[0][openingOfferState],
                openingOfferTransactionHash: result[0][openingOfferTransactionHash],
                openingOfferTransactionCreationTime: result[0][openingOfferTransactionCreationTime],
                openingOfferTransactionCreationBlockNumber: result[0][openingOfferTransactionCreationBlockNumber],
                cancelingOfferState: result[0][cancelingOfferState],
                offerCancellationTransactionHash: result[0][offerCancellationTransactionHash],
                offerCancellationTransactionCreationTime: result[0][offerCancellationTransactionCreationTime],
                offerCancellationTransactionCreationBlockNumber: result[0][offerCancellationTransactionCreationBlockNumber],
                editingOfferState: result[0][editingOfferState],
                offerEditingTransactionHash: result[0][offerEditingTransactionHash],
                offerEditingTransactionCreationTime: result[0][offerEditingTransactionCreationTime],
                offerEditingTransactionCreationBlockNumber: result[0][offerEditingTransactionCreationBlockNumber],
                approveToTakeState: result[0][approveToTakeState],
                approveToTakeTransactionHash: result[0][approveToTakeTransactionHash],
                approveToTakeTransactionCreationTime: result[0][approveToTakeTransactionCreationTime],
                approveToTakeTransactionCreationBlockNumber: result[0][approveToTakeTransactionCreationBlockNumber],
                takingOfferState: result[0][takingOfferState],
                takingOfferTransactionHash: result[0][takingOfferTransactionHash],
                takingOfferTransactionCreationTime: result[0][takingOfferTransactionCreationTime],
                takingOfferTransactionCreationBlockNumber: result[0][takingOfferTransactionCreationBlockNumber]
            )
        } else {
            logger.notice("getOffer: no offer found with B64 ID \(_id)")
            return nil
        }
    }
    
    /**
     Deletes all persistently stored settlement methods, their private data and corresponding initialization vectors (if any) associated with the specified offer ID and chain ID in `table`, and then persistently stores each settlement method and private data string tuples in the supplied `Array` into `table`, associating each one with the supplied offer ID and chain ID. Private settlement method data is encrypted with `databaseKey` and a new initialization vector.
     
     - Parameters:
        - offerID: The ID of the offer or swap to be associated with the settlement methods.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - settlementMethods: The settlement methods to be persistently stored, as a tuple containing a string and an optional string, in that order. The first element in a tuple is the public settlement method data, including price, currency and type. The second element element in a tuple is private data (such as an address or bank account number) for the settlement method, if any.
        - table: The database table into which the settlement methods will be inserted.
     */
    private func insertSettlementMethodsIntoTable(offerID: String, _chainID: String, settlementMethods _settlementMethods: [(String, String?)], table: Table) throws {
        _ = try databaseQueue.sync {
            try connection.run(table.filter(id == offerID && chainID == _chainID).delete())
            for _settlementMethod in _settlementMethods {
                let (privateDataString, initializationVectorString) = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: _settlementMethod.1)
                try connection.run(table.insert(
                    id <- offerID,
                    chainID <- _chainID,
                    settlementMethod <- _settlementMethod.0,
                    privateSettlementMethodData <- privateDataString,
                    privateSettlementMethodDataInitializationVector <- initializationVectorString
                ))
            }
        }
    }
    
    /**
     Removes every persistently stored settlement method associated with an offer ID equal to `offerID` and a chain ID equal to `chainID` from `table`.
     
     - Parameters:
        - offerID: The ID of the offer for which associated settlement methods should be removed.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - table: A database table from which settlement methods will be deleted.
     */
    private func deleteSettlementMethodsFromTable(offerID: String, _chainID: String, table: Table) throws {
        _ = try databaseQueue.sync {
            try connection.run(table.filter(id == offerID && chainID == _chainID).delete())
        }
    }
    
    /**
     Encrypts `privateSettlementMethodData` with `databaseKey` along with the initialization vector used for encryption, and returns both as Base64 encoded strings of bytes within a tuple, or returns a tuple of two `nil` values if `privateSettlementMethodData` is `nil`.
     
     - Parameter privateSettlementMethodData: The string of private data to be symmetrically encrypted with `databaseKey`.
     - Returns: A tuple containing to optional strings. If `privateSettlementMethodData` is not `nil`, the first will be `privateSettlementMethodData` encrypted with `databaseKey` and a new initialization vector as a Base64 encoded string of bytes, and the second will be the initialization vector used to encrypt `privateSettlementMethodData`, also as a Base64 encoded string of bytes. If `privateSettlementMethodData` is `nil`, both strings will be `nil`
     */
    private func encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: String?) throws -> (String?, String?) {
        var privateCipherDataString: String? = nil
        var initializationVectorString: String? = nil
        let privateBytes = privateSettlementMethodData?.bytes
        if let privateBytes = privateBytes {
            let privateData = Data(privateBytes)
            let encryptedData = try databaseKey.encrypt(data: privateData)
            privateCipherDataString = encryptedData.encryptedData.base64EncodedString()
            initializationVectorString = encryptedData.initializationVectorData.base64EncodedString()
        }
        return (privateCipherDataString, initializationVectorString)
    }
    
    /**
     Decrypts `privateSettlementMethodData` with `databaseKey` and `privateSettlementMethodDataInitializationVector` and then returns the result as a UTF-8 string, or returns `nil` if `privateSettlementMethodData` or `privateSettlementMethodDataInitializationVector` is `nil` or if decryption is unsuccessful.
     
     - Parameters:
        - privateSettlementMethodData: The private data to be decrypted, as a Base64 encoded string of bytes.
        - privateSettlementMethodDataInitializationVector: The initialization vector that will be used to decrypt `privateSettlementMethodData`, as a Base64 encoded string of bytes.
     
     - Returns: An optional string that will either be a UTF-8 string made from the results of decryption, or `nil` if either of the parameters are `nil` or if decryption is unsuccessful.
     */
    private func decryptPrivateSwapSettlementMethodData(privateSettlementMethodData: String?, privateSettlementMethodDataInitializationVector: String?) throws -> String? {
        var decryptedPrivateDataString: String? = nil
        if let privateDataCipherString = privateSettlementMethodData, let privateDataInitializationVectorString = privateSettlementMethodDataInitializationVector {
            let privateCipherData = Data(base64Encoded: privateDataCipherString)
            let privateDataInitializationVector = Data(base64Encoded: privateDataInitializationVectorString)
            if let privateCipherData = privateCipherData, let privateDataInitializationVector = privateDataInitializationVector {
                let privateDataObject = SymmetricallyEncryptedData(data: privateCipherData, iv: privateDataInitializationVector)
                if let decryptedPrivateData = try? databaseKey.decrypt(data: privateDataObject) {
                    decryptedPrivateDataString = String(bytes: decryptedPrivateData, encoding: .utf8)
                }
            }
        }
        return decryptedPrivateDataString
    }
    
    /**
     Attempts to decrypt the supplied cipher data using `databaseKey` and the supplied initialization vector string.
     
     - Parameters:
        - privateDataCipherString: The cipher data to be decrypted, as a Base64-encoded string.
        - privateDataInitializationVector: The initialization vector with which to decrypt `privateDataCipherString`.
        - decryptionFailureHandler: A closure that will be executed if decryption fails.
        - decodingFailureHandler: A closure that will be executed if decoding the cipher string or initialization vector fails.
     
     - Returns: `privateDataCipherString` as a decrypted string, or `nil` if the decoding and decryption process fails.
     */
    private func decryptSettlementMethodFromTable(
        privateDataCipherString: String,
        privateDataInitializationVectorString: String,
        decryptionFailureHandler: () -> Void,
        decodingFailureHandler: () -> Void
    ) -> String? {
        let privateCipherData = Data(base64Encoded: privateDataCipherString)
        let privateDataInitializationVector = Data(base64Encoded: privateDataInitializationVectorString)
        if let privateCipherData = privateCipherData, let privateDataInitializationVector = privateDataInitializationVector {
            let privateDataObject = SymmetricallyEncryptedData(data: privateCipherData, iv: privateDataInitializationVector)
            if let decryptedPrivateData = try? databaseKey.decrypt(data: privateDataObject) {
                return String(bytes: decryptedPrivateData, encoding: .utf8)
            } else {
                decryptionFailureHandler()
                return nil
            }
        } else {
            decodingFailureHandler()
            return nil
        }
    }
    
    /**
     Retrieves and decrypts the persistently stored settlement methods their private data (if any) associated with the specified offer ID and chain ID from `table`, or returns `nil` if no such settlement methods are present.
     
     - Parameters:
        - offerID: The ID of the offer for which settlement methods should be returned, as a Base64-`String` of bytes.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - table: The database table from which the settlement methods will be retrieved.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is `nil`.
     
     - Returns: `nil` if no such settlement methods are found, or an `Array` of tuples containing a string and an optional string, the first of which is a settlement method associated with `id`, the second of which is the private data associated with that settlement method, or `nil` if no such data is found or if it cannot be decrypted.
     */
    private func getAndDecryptSettlementMethodsFromTable(offerID: String, _chainID: String, table: Table) throws -> [(String, String?)]? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(table.filter(id == offerID && chainID == _chainID))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getAndDecryptSettlementMethodsFromTable call")
        }
        let result = try Array(rowIterator!)
        if result.count > 0 {
            var settlementMethodsArray: [(String, String?)] = []
            for (index, _) in result.enumerated() {
                var decryptedPrivateDataString: String? = nil
                let privateDataCipherString = result[index][privateSettlementMethodData]
                let privateDataInitializationVectorString = result[index][privateSettlementMethodDataInitializationVector]
                if let privateDataCipherString = privateDataCipherString, let privateDataInitializationVectorString = privateDataInitializationVectorString {
                    decryptedPrivateDataString = decryptSettlementMethodFromTable(
                        privateDataCipherString: privateDataCipherString,
                        privateDataInitializationVectorString: privateDataInitializationVectorString,
                        decryptionFailureHandler: {
                            logger.error("getAndDecryptSettlementMethodsFromTable: unable to get string from decoded private data using utf8 encoding for offer with B64 ID \(offerID)")
                        },
                        decodingFailureHandler: {
                            logger.error("getAndDecryptSettlementMethodsFromTable: found private data for offer with B64 ID \(offerID) but could not decode bytes from strings")
                        }
                    )
                } else {
                    logger.notice("getAndDecryptSettlementMethodsFromTable: did not find private settlement method data for settlement method for offer with B64 ID \(offerID)")
                }
                settlementMethodsArray.append((result[index][settlementMethod], decryptedPrivateDataString))
            }
            logger.notice("getAndDecryptSettlementMethodsFromTable: returning \(settlementMethodsArray.count) for offer with B64 ID \(offerID)")
            return settlementMethodsArray
        } else {
            logger.notice("getAndDecryptSettlementMethodsFromTable: none found for offer with B64 ID \(offerID)")
            return nil
        }
    }
    
    /**
     Calls `DatabaseService.insertSettlementMethodsIntoTable`, passing all parameters passed to this function and the table of offers' current settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer or swap to be associated with the settlement methods.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - settlementMethods: The settlement methods to be persistently stored, as tuples containing a string and an optional string, in that order. The first element in a tuple is the public settlement method data, including price, currency and type. The second element element in a tuple is private data (such as an address or bank account number) for the settlement method, if any.
     */
    func storeOfferSettlementMethods(offerID: String, _chainID: String, settlementMethods _settlementMethods: [(String, String?)]) throws {
        try insertSettlementMethodsIntoTable(offerID: offerID, _chainID: _chainID, settlementMethods: _settlementMethods, table: offerSettlementMethods)
        logger.notice("storeOfferSettlementMethods: stored \(_settlementMethods.count) for offer with B64 ID \(offerID)")
    }
    
    /**
     Calls `DatabaseService.deleteSettlementMethodsFromTable`, passing all parameters passed to this function and the table of the offer's current settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer for which associated settlement methods should be removed.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
     */
    func deleteOfferSettlementMethods(offerID: String, _chainID: String) throws {
        try deleteSettlementMethodsFromTable(offerID: offerID, _chainID: _chainID, table: offerSettlementMethods)
        logger.notice("deleteOfferSettlementMethods: deleted for offer with B64 ID \(offerID)")
    }

    /**
     Calls `DatabaseService.getAndDecryptSettlementMethodsFromTable`, passing all parameters passed to this function and the table of the offer's current settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer for which settlement methods should be returned, as a Base64-`String` of bytes.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
     
     - Returns: The value returned by `DatabaseService.getAndDecryptSettlementMethodsFromTable`.
     */
    func getOfferSettlementMethods(offerID: String, _chainID: String) throws -> [(String, String?)]? {
        logger.notice("getOfferSettlementMethods: getting for offer with B64 ID \(offerID)")
        return try getAndDecryptSettlementMethodsFromTable(offerID: offerID, _chainID: _chainID, table: offerSettlementMethods)
    }
    
    /**
     Calls `DatabaseService.insertSettlementMethodsIntoTable`, passing all parameters passed to this function and the table of offers' pending settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer or swap to be associated with the pending settlement methods.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - settlementMethods: The pending settlement methods to be persistently stored, as a tuple containing a string and an optional string, in that order. The first element in a tuple is the public settlement method data, including price, currency and type. The second element element in a tuple is private data (such as an address or bank account number) for the settlement method, if any.
     */
    func storePendingOfferSettlementMethods(offerID: String, _chainID: String, pendingSettlementMethods _pendingSettlementMethods: [(String, String?)]) throws {
        try insertSettlementMethodsIntoTable(offerID: offerID, _chainID: _chainID, settlementMethods: _pendingSettlementMethods, table: pendingOfferSettlementMethods)
        logger.notice("storePendingOfferSettlementMethods: stored \(_pendingSettlementMethods.count) for offer with B64 ID \(offerID)")
    }
    
    /**
     Calls `DatabaseService.deleteSettlementMethodsFromTable`, passing all parameters passed to this function and the table of the offer's pending settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer for which associated pending settlement methods should be removed.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these pending settlement methods exists, as a `String`.
     */
    func deletePendingOfferSettlementMethods(offerID: String, _chainID: String) throws {
        try deleteSettlementMethodsFromTable(offerID: offerID, _chainID: _chainID, table: pendingOfferSettlementMethods)
        logger.notice("deletePendingOfferSettlementMethods: deleted for offer with B64 ID \(offerID)")
    }

    /**
     Calls `DatabaseService.getAndDecryptSettlementMethodsFromTable`, passing all parameters passed to this function and the table of the offer's pending settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer for which pending settlement methods should be returned, as a Base64-`String` of bytes.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these pending settlement methods exists, as a `String`.
     
     - Returns: The value returned by `DatabaseService.getAndDecryptSettlementMethodsFromTable`.
     */
    func getPendingOfferSettlementMethods(offerID: String, _chainID: String) throws -> [(String, String?)]? {
        logger.notice("getPendingOfferSettlementMethods: getting for offer with B64 ID \(offerID)")
        return try getAndDecryptSettlementMethodsFromTable(offerID: offerID, _chainID: _chainID, table: pendingOfferSettlementMethods)
    }
    
    /**
     Persistently stores a key pair associated with an interface ID.
     
     - Note: This function is used exclusively by `KeyManagerService`
     
     - Parameters:
        - interfaceId: The interface ID of the key pair as a byte array encoded to a hexadecimal `String`.
        - publicKey: The public key of the key pair as a byte array encoded to a hexadecimal `String`.
        - privateKey: The private key of the key pair as a byte array encoded to a hexadecimal `String`.
     */
    func storeKeyPair(interfaceId interf_id: String, publicKey pub_key: String, privateKey priv_key: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(keyPairs.insert(interfaceId <- interf_id, publicKey <- pub_key, privateKey <- priv_key))
                logger.notice("storeKeyPair: stored with interface ID \(interf_id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: KeyPair.interfaceId" {
                // A KeyPair with the specified interface ID already exists in the database, so we do nothing
                logger.notice("storeKeyPair: key pair with interface ID \(interf_id) already exists in database")
            }
        }
    }
    
    /**
     Retrieves the persistently stored key pair associated with the given interface ID, or returns `nil` if no such key pair is present.
     
     - Parameter interfaceId: The interface ID of the desired key pair as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DatabaseKeyPair` if a key pair with the specified interface ID is found, or `nil` if such a key pair is not found.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple key pairs are found with the same interface ID or if the interface ID of the key pair returned from the database does not match `interfaceId`.
     */
    func getKeyPair(interfaceId interfId: String) throws -> DatabaseKeyPair? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(keyPairs.filter(interfaceId == interfId))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getKeyPair call")
        }
        let result = try Array(rowIterator!)
        if (result.count > 1) {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple key pairs found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            logger.notice("getKeyPair: returning key pair with interface ID \(interfId)")
            return DatabaseKeyPair(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey], privateKey: result[0][privateKey])
        } else {
            logger.notice("getKeyPair: no key pair found with interface ID \(interfId)")
            return nil
        }
    }
    
    /**
     Persistently stores a public key associated with an interface ID.
     
     - Parameters:
        - interfaceId: The interface ID of the key pair as a byte array encoded to a hexadecimal `String`.
        - publicKey: The public key to be stored, as a byte array encoded to a hexadecimal `String`.
     */
    func storePublicKey(interfaceId interf_id: String, publicKey pub_key: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(publicKeys.insert(interfaceId <- interf_id, publicKey <- pub_key))
                logger.notice("storePublicKey: stored with interface ID \(interf_id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: PublicKey.interfaceId" {
                // A PublicKey with the specified interface ID already exists in the database, so we do nothing
                logger.notice("storePublicKey: public key with interface ID \(interf_id) already exists in database")
            }
        }
    }
    
    /**
     Retrieves the persistently stored public key associated with the given interface ID, or returns `nil` if no such key is found.
     
     - Parameter interfaceId: The interface ID of the public key as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DatabasePublicKey` if a public key with the specified interface ID is found, or `nil` if no such public key is found.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple public keys are found with the same interface ID or if the interface ID of the public key returned from the database does not match `interfaceId`.
     */
    func getPublicKey(interfaceId interfId: String) throws -> DatabasePublicKey? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(publicKeys.filter(interfaceId == interfId))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getPublicKey call")
        }
        let result = try Array(rowIterator!)
        if (result.count > 1) {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple public keys found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            logger.notice("getPublicKey: returning public key with interface ID \(interfId)")
            return DatabasePublicKey(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey])
        } else {
            logger.notice("getPublicKey: no public key found with interface ID \(interfId)")
            return nil
        }
    }
    
    /**
     Persistently stores a `DatabaseSwap`. If a `DatabaseSwap` with an offer ID equal to that of `swap` already exists in the database, this does nothing.
    
     - Parameter swap: The `swap` to be persistently stored.
     */
    func storeSwap(swap: DatabaseSwap) throws {
        let encryptedMakerData = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: swap.makerPrivateSettlementMethodData)
        let encryptedTakerData = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: swap.takerPrivateSettlementMethodData)
        try databaseQueue.sync {
            do {
                try connection.run(swaps.insert(
                    id <- swap.id,
                    isCreated <- swap.isCreated,
                    requiresFill <- swap.requiresFill,
                    maker <- swap.maker,
                    makerInterfaceID <- swap.makerInterfaceID,
                    taker <- swap.taker,
                    takerInterfaceID <- swap.takerInterfaceID,
                    stablecoin <- swap.stablecoin,
                    amountLowerBound <- swap.amountLowerBound,
                    amountUpperBound <- swap.amountUpperBound,
                    securityDepositAmount <- swap.securityDepositAmount,
                    takenSwapAmount <- swap.takenSwapAmount,
                    serviceFeeAmount <- swap.serviceFeeAmount,
                    serviceFeeRate <- swap.serviceFeeRate,
                    onChainDirection <- swap.onChainDirection,
                    settlementMethod <- swap.onChainSettlementMethod,
                    makerPrivateSettlementMethodData <- encryptedMakerData.0,
                    makerPrivateSettlementMethodDataInitializationVector <- encryptedMakerData.1,
                    takerPrivateSettlementMethodData <- encryptedTakerData.0,
                    takerPrivateSettlementMethodDataInitializationVector <- encryptedTakerData.1,
                    protocolVersion <- swap.protocolVersion,
                    isPaymentSent <- swap.isPaymentSent,
                    isPaymentReceived <- swap.isPaymentReceived,
                    hasBuyerClosed <- swap.hasBuyerClosed,
                    hasSellerClosed <- swap.hasSellerClosed,
                    disputeRaiser <- swap.onChainDisputeRaiser,
                    chainID <- swap.chainID,
                    swapState <- swap.state,
                    swapRole <- swap.role,
                    approveToFillState <- swap.approveToFillState,
                    approveToFillTransactionHash <- swap.approveToFillTransactionHash,
                    approveToFillTransactionCreationTime <- swap.approveToFillTransactionCreationTime,
                    approveToFillTransactionCreationBlockNumber <- swap.approveToFillTransactionCreationBlockNumber,
                    fillingSwapState <- swap.fillingSwapState,
                    fillingSwapTransactionHash <- swap.fillingSwapTransactionHash,
                    fillingSwapTransactionCreationTime <- swap.fillingSwapTransactionCreationTime,
                    fillingSwapTransactionCreationBlockNumber <- swap.fillingSwapTransactionCreationBlockNumber,
                    reportPaymentSentState <- swap.reportPaymentSentState,
                    reportPaymentSentTransactionHash <- swap.reportPaymentSentTransactionCreationTime,
                    reportPaymentSentTransactionCreationTime <- swap.reportPaymentSentTransactionCreationTime,
                    reportPaymentSentTransactionCreationBlockNumber <- swap.reportPaymentSentTransactionCreationBlockNumber,
                    reportPaymentReceivedState <- swap.reportPaymentReceivedState,
                    reportPaymentReceivedTransactionHash <- swap.reportPaymentReceivedTransactionCreationTime,
                    reportPaymentReceivedTransactionCreationTime <- swap.reportPaymentReceivedTransactionCreationTime,
                    reportPaymentReceivedTransactionCreationBlockNumber <- swap.reportPaymentReceivedTransactionCreationBlockNumber,
                    closeSwapState <- swap.closeSwapState,
                    closeSwapTransactionHash <- swap.closeSwapTransactionCreationTime,
                    closeSwapTransactionCreationTime <- swap.closeSwapTransactionCreationTime,
                    closeSwapTransactionCreationBlockNumber <- swap.closeSwapTransactionCreationBlockNumber
                ))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: Swap.id" {
                // A swap with the specified ID already exists in the database, so we do nothing
                logger.notice("storeSwap: swap with B64 ID \(swap.id) already exists in database")
            }
        }
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `requiresFill` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - requiresFill: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `requiresFill` field.
     */
    func updateSwapRequiresFill(swapID: String, chainID _chainID: String, requiresFill _requiresFill: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(requiresFill <- _requiresFill))
        }
        logger.notice("updateSwapState: set value to \(_requiresFill) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `makerPrivateSettlementMethodData` and `makerPrivateSettlementMethodDataInitializationVector` fields with the results of encrypting `data`.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - data: New private settlement method data belonging to the maker of the swap with the specified ID and chain ID, to be encrypted and stored.
     */
    func updateSwapMakerPrivateSettlementMethodData(swapID: String, chainID _chainID: String, data: String?) throws {
        let encryptedData = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: data)
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(makerPrivateSettlementMethodData <- encryptedData.0, makerPrivateSettlementMethodDataInitializationVector <- encryptedData.1))
        }
        logger.notice("updateSwapMakerPrivateSettlementMethodData: updated for \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `takerPrivateSettlementMethodData` and `takerPrivateSettlementMethodDataInitializationVector` fields with the results of encrypting `data`.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - data: New private settlement method data belonging to the taker of the swap with the specified ID and chain ID, to be encrypted and stored.
     */
    func updateSwapTakerPrivateSettlementMethodData(swapID: String, chainID _chainID: String, data: String?) throws {
        let encryptedData = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: data)
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(takerPrivateSettlementMethodData <- encryptedData.0, takerPrivateSettlementMethodDataInitializationVector <- encryptedData.1))
        }
        logger.notice("updateSwapTakerPrivateSettlementMethodData: updated for \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `isPaymentSent` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - isPaymentSent: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `isPaymentSent` field.
     */
    func updateSwapIsPaymentSent(swapID: String, chainID _chainID: String, isPaymentSent _isPaymentSent: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(isPaymentSent <- _isPaymentSent))
        }
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `isPaymentReceived` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - isPaymentReceived: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `isPaymentReceived` field.
     */
    func updateSwapIsPaymentReceived(swapID: String, chainID _chainID: String, isPaymentReceived _isPaymentReceived: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(isPaymentReceived <- _isPaymentReceived))
        }
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `hasBuyerClosed` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - hasBuyerClosed: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `hasBuyerClosed` field.
     */
    func updateSwapHasBuyerClosed(swapID: String, chainID _chainID: String, hasBuyerClosed _hasBuyerClosed: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(hasBuyerClosed <- _hasBuyerClosed))
        }
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `hasSellerClosed` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - hasSellerClosed: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `hasSellerClosed` field.
     */
    func updateSwapHasSellerClosed(swapID: String, chainID _chainID: String, hasSellerClosed _hasSellerClosed: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(hasSellerClosed <- _hasSellerClosed))
        }
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `state` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `state` field.
     */
    func updateSwapState(swapID: String, chainID _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(swapState <- state))
        }
        logger.notice("updateSwapState: set value to \(state) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `approveToFillState` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `approveToFillState` field.
     */
    func updateSwapApproveToFillState(swapID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(approveToFillState <- state))
        }
        logger.notice("updateSwapApproveToFillState: set value to \(state) for offer with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `approveToFillTransactionHash`, `approveToFillTransactionCreationTime`, and `approveToFillTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `approveToFillTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `approveToFillTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseFill`'s `approveToFillTransactionCreationBlockNumber` field.
     */
    func updateSwapApproveToFillData(swapID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID)
                .update(
                    approveToFillTransactionHash <- transactionHash,
                    approveToFillTransactionCreationTime <- transactionCreationTime,
                    approveToFillTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateOfferApproveToFillData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `fillingSwapState` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `fillingSwapState` field.
     */
    func updateFillingSwapState(swapID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(fillingSwapState <- state))
        }
        logger.notice("updateFillingSwapState: set value to \(state) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `fillingSwapTransactionHash`, `fillingSwapTransactionCreationTime`, and `fillingSwapTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `fillingSwapTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `fillingSwapTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `fillingSwapTransactionCreationBlockNumber` field.
     */
    func updateFillingSwapData(swapID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID)
                .update(
                    fillingSwapTransactionHash <- transactionHash,
                    fillingSwapTransactionCreationTime <- transactionCreationTime,
                    fillingSwapTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateFillingSwapData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `reportPaymentSentState` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentSentState` field.
     */
    func updateReportPaymentSentState(swapID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(reportPaymentSentState <- state))
        }
        logger.notice("updateReportPaymentSentState: set value to \(state) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `reportPaymentSentTransactionHash`, `reportPaymentSentTransactionCreationTime`, and `reportPaymentSentTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentSentTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentSentTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentSentTransactionCreationBlockNumber` field.
     */
    func updateReportPaymentSentData(swapID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID)
                .update(
                    reportPaymentSentTransactionHash <- transactionHash,
                    reportPaymentSentTransactionCreationTime <- transactionCreationTime,
                    reportPaymentSentTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateReportPaymentSentData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `reportPaymentReceivedState` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentReceivedState` field.
     */
    func updateReportPaymentReceivedState(swapID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(reportPaymentReceivedState <- state))
        }
        logger.notice("updateReportPaymentReceivedState: set value to \(state) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `reportPaymentReceivedTransactionHash`, `reportPaymentReceivedTransactionCreationTime`, and `reportPaymentReceivedTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentReceivedTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentReceivedTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `reportPaymentReceivedTransactionCreationBlockNumber` field.
     */
    func updateReportPaymentReceivedData(swapID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID)
                .update(
                    reportPaymentReceivedTransactionHash <- transactionHash,
                    reportPaymentReceivedTransactionCreationTime <- transactionCreationTime,
                    reportPaymentReceivedTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateReportPaymentReceivedData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `closeSwapState` field.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - state: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `closeSwapState` field.
     */
    func updateCloseSwapState(swapID: String, _chainID: String, state: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).update(closeSwapState <- state))
        }
        logger.notice("updateCloseSwapState: set value to \(state) for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Updates a persistently stored `DatabaseSwap`'s `closeSwapTransactionHash`, `closeSwapTransactionCreationTime`, and `closeSwapTransactionCreationBlockNumber` fields.
     
     - Parameters:
        - swapID: The ID of the swap to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swap to be updated, as a `String`.
        - transactionHash: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `closeSwapTransactionHash` field.
        - transactionCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `closeSwapTransactionCreationTime` field.
        - latestBlockNumberAtCreationTime: The new value that will be assigned to the persistently stored `DatabaseSwap`'s `closeSwapTransactionCreationBlockNumber` field.
     */
    func updateCloseSwapData(swapID: String, _chainID: String, transactionHash: String?, transactionCreationTime: String?, latestBlockNumberAtCreationTime: Int?) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID)
                .update(
                    closeSwapTransactionHash <- transactionHash,
                    closeSwapTransactionCreationTime <- transactionCreationTime,
                    closeSwapTransactionCreationBlockNumber <- latestBlockNumberAtCreationTime
                ))
        }
        logger.notice("updateCloseSwapData: set values to \(transactionHash ?? "nil"), \(transactionCreationTime ?? "nil"), and \(latestBlockNumberAtCreationTime.map(String.init) ?? "nil") for swap with B64 ID \(swapID), if present")
    }
    
    /**
     Removes every `DatabaseSwap` with a swapID equal to `swapID` and a chain ID equal to `chainID` from persistent storage.
     
     - Parameters:
        - swapID: The ID of the swaps to be removed, as a Base64-`String` of bytes.
        - chainID: The chain ID of the swaps to be removed as a `String`.
     */
    func deleteSwaps(swapID: String, chainID _chainID: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(swaps.filter(id == swapID && chainID == _chainID).delete())
        }
        logger.notice("deleteSwaps: deleted swaps with B64 ID \(swapID) and chain ID \(_chainID), if present")
    }
    
    /**
     Retrieves the persistently stored `DatabaseSwap` with the specified offer ID, or returns `nil` if no such event is present.
     
     - Parameter id: The swap ID of the `DatabaseSwap` to return, as a Base64-`String` of bytes.
     
     - Throws: A `DatabaseServiceError.unexpectedQueryResult` if multiple `DatabaseSwap`s are found with the same swap ID or if the swap ID of the `DatabaseSwap` returned from the database does not match `id`.
     
     - Returns: A `DatabaseSwap` corresponding to `id`, or `nil` if no such `DatabaseSwap` is found.
     */
    func getSwap(id _id: String) throws -> DatabaseSwap? {
        let rowIterator = try databaseQueue.sync {
            try connection.prepareRowIterator(swaps.filter(id == _id))
        }
        let result = try Array(rowIterator)
        if result.count > 1 {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple Swaps found with given swap id \(_id)")
        } else if result.count == 1 {
            guard result[0][id] == _id else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Returned swap ID \(result[0][id]) did not match specified swap ID \(_id)")
            }
            let decryptedMakerPrivateData = try decryptPrivateSwapSettlementMethodData(
                privateSettlementMethodData: result[0][makerPrivateSettlementMethodData],
                privateSettlementMethodDataInitializationVector: result[0][makerPrivateSettlementMethodDataInitializationVector]
            )
            let decryptedTakerPrivateData = try decryptPrivateSwapSettlementMethodData(
                privateSettlementMethodData: result[0][takerPrivateSettlementMethodData],
                privateSettlementMethodDataInitializationVector: result[0][takerPrivateSettlementMethodDataInitializationVector]
            )
            logger.notice("getSwap: returning swap with B64 ID \(_id)")
            return DatabaseSwap(
                id: result[0][id],
                isCreated: result[0][isCreated],
                requiresFill: result[0][requiresFill],
                maker: result[0][maker],
                makerInterfaceID: result[0][makerInterfaceID],
                taker: result[0][taker],
                takerInterfaceID: result[0][takerInterfaceID],
                stablecoin: result[0][stablecoin],
                amountLowerBound: result[0][amountLowerBound],
                amountUpperBound: result[0][amountUpperBound],
                securityDepositAmount: result[0][securityDepositAmount],
                takenSwapAmount: result[0][takenSwapAmount],
                serviceFeeAmount: result[0][serviceFeeAmount],
                serviceFeeRate: result[0][serviceFeeRate],
                onChainDirection: result[0][onChainDirection],
                onChainSettlementMethod: result[0][settlementMethod],
                makerPrivateSettlementMethodData: decryptedMakerPrivateData,
                takerPrivateSettlementMethodData: decryptedTakerPrivateData,
                protocolVersion: result[0][protocolVersion],
                isPaymentSent: result[0][isPaymentSent],
                isPaymentReceived: result[0][isPaymentReceived],
                hasBuyerClosed: result[0][hasBuyerClosed],
                hasSellerClosed: result[0][hasSellerClosed],
                onChainDisputeRaiser: result[0][disputeRaiser],
                chainID: result[0][chainID],
                state: result[0][swapState],
                role: result[0][swapRole],
                approveToFillState: result[0][approveToFillState],
                approveToFillTransactionHash: result[0][approveToFillTransactionHash],
                approveToFillTransactionCreationTime: result[0][approveToFillTransactionCreationTime],
                approveToFillTransactionCreationBlockNumber: result[0][approveToFillTransactionCreationBlockNumber],
                fillingSwapState: result[0][fillingSwapState],
                fillingSwapTransactionHash: result[0][fillingSwapTransactionHash],
                fillingSwapTransactionCreationTime: result[0][fillingSwapTransactionCreationTime],
                fillingSwapTransactionCreationBlockNumber: result[0][fillingSwapTransactionCreationBlockNumber],
                reportPaymentSentState: result[0][reportPaymentSentState],
                reportPaymentSentTransactionHash: result[0][reportPaymentSentTransactionHash],
                reportPaymentSentTransactionCreationTime: result[0][reportPaymentSentTransactionCreationTime],
                reportPaymentSentTransactionCreationBlockNumber: result[0][reportPaymentSentTransactionCreationBlockNumber],
                reportPaymentReceivedState: result[0][reportPaymentReceivedState],
                reportPaymentReceivedTransactionHash: result[0][reportPaymentReceivedTransactionHash],
                reportPaymentReceivedTransactionCreationTime: result[0][reportPaymentReceivedTransactionCreationTime],
                reportPaymentReceivedTransactionCreationBlockNumber: result[0][reportPaymentReceivedTransactionCreationBlockNumber],
                closeSwapState: result[0][closeSwapState],
                closeSwapTransactionHash: result[0][closeSwapTransactionHash],
                closeSwapTransactionCreationTime: result[0][closeSwapTransactionCreationTime],
                closeSwapTransactionCreationBlockNumber: result[0][closeSwapTransactionCreationBlockNumber]
            )
        } else {
            logger.notice("getSwap: no swap found with B64 ID \(_id)")
            return nil
        }
    }
    
    /**
     Persistently stores the settlement method string and private data string, associating them with the given UUID string. The private settlement method data is encrypted with `databaseKey` and a new initialization vector.
     
     - Parameters:
        - id: The ID of the settlement method to be stored, as a Type  4 UUID string.
        - settlementMethod: The public data of the settlement method to be  persistently stored, including currency and  type.
        - privateData: The private data of the settlement method, such as an address or bank account number for the settlement method, if any.
     */
    func storeUserSettlementMethod(id: String, settlementMethod settlementMethodString: String, privateData: String?) throws {
        _ = try databaseQueue.sync {
            let (privateDataString, initializationVectorString) = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: privateData)
            try connection.run(userSettlementMethods.insert(
                settlementMethodID <- id,
                settlementMethod <- settlementMethodString,
                privateSettlementMethodData <- privateDataString,
                privateSettlementMethodDataInitializationVector <- initializationVectorString
            ))
        }
        logger.notice("storeUserSettlementMethod: stored \(id)")
    }
    
    /**
     Updates the private settlement method data of a persistently stored settlement method with the given ID. The new private settlement method data is encrypted with `databaseKey` and a new initialization vector.
     
     - Parameters:
        - id: The ID of the settlement method, the private data of which this will update.
        - privateData: The new private settlement method data with which this will replace the current private settlement method data of the settlement method with the ID `id`.
     */
    func updateUserSettlementMethod(id: String, privateData: String?) throws {
        logger.notice("updateUserSettlementMethod: updating \(id)")
        _ = try databaseQueue.sync {
            let (privateDataString, initializationVectorString) = try encryptPrivateSwapSettlementMethodData(privateSettlementMethodData: privateData)
            try connection.run(
                userSettlementMethods.filter(
                    settlementMethodID == id
                ).update(
                    privateSettlementMethodData <- privateDataString,
                    privateSettlementMethodDataInitializationVector <- initializationVectorString
                )
            )
        }
    }
    
    /**
     Removes every persistently stored settlement method with an ID equal to `id` from the table of the user's settlement methods.
     
     - Parameter id: The ID of the settlement method(s) to be deleted.
     */
    func deleteUserSettlementMethod(id: String) throws {
        logger.notice("deleteUserSettlementMethod: deleting \(id)")
        _ = try databaseQueue.sync {
            try connection.run(userSettlementMethods.filter(settlementMethodID == id).delete())
        }
    }
    
    /**
     Retrieves and decrypts the persistently stored settlement method and its private data (if any) associated with the specified settlement method ID from the table of the user's settlement methods, or returns `nil` if no such settlement method is found.
     
     - Parameter id: The ID of the settlement method to be retrieved, as a Type 4 UUID string.
     
     - Throws `DatabaseServiceError.unexpectedNilError` If the database query returns a non-empty result that somehow doesn't have a first element.
     
     - Returns: `nil` if no such settlement method is found, or a tuple containing a string and an optional string, the first of which is a settlement method associated with `id`, the second of which is the private data associated with that settlement method, or `nil` if no such data is found or if it cannot be decrypted.
     */
    func getUserSettlementMethod(id: String) throws -> (String, String?)? {
        logger.notice("getUserSettlementMethod: getting \(id)")
        let rowIterator = try databaseQueue.sync {
            try connection.prepareRowIterator(userSettlementMethods.filter(settlementMethodID == id))
        }
        let result = try Array(rowIterator)
        if result.count == 1 {
            guard let element = result.first else {
                throw DatabaseServiceError.unexpectedNilError(desc: "Database result size was 1 but no first element was found during getUserSettlementMethod call")
            }
            var decryptedPrivateDataString: String? = nil
            let privateDataCipherString = element[privateSettlementMethodData]
            let privateDataInitializationVectorString = element[privateSettlementMethodDataInitializationVector]
            if let privateDataCipherString = privateDataCipherString, let privateDataInitializationVectorString = privateDataInitializationVectorString {
                decryptedPrivateDataString = decryptSettlementMethodFromTable(
                    privateDataCipherString: privateDataCipherString,
                    privateDataInitializationVectorString: privateDataInitializationVectorString,
                    decryptionFailureHandler: {
                        logger.error("getUserSettlementMethod: unable to get string from decoded private data using utf8 encoding for \(id)")
                    },
                    decodingFailureHandler: {
                        logger.error("getUserSettlementMethod: unable to get string from decoded private data using utf8 encoding for \(id)")
                    }
                )
            } else {
                logger.notice("getUserSettlementMethod: did not find private settlement method data for \(id)")
            }
            return (element[settlementMethod], decryptedPrivateDataString)
        } else {
            logger.notice("getUserSettlementMethod: \(id) not found")
            return nil
        }
    }
    
}

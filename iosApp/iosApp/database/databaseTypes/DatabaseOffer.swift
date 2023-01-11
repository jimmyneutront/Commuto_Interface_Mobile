//
//  DatabaseOffer.swift
//  iosApp
//
//  Created by jimmyt on 6/26/22.
//  Copyright © 2022 orgName. All rights reserved.
//

/**
 Represents an `Offer` in a form that can be persistently stored in a database, minus settlement methods.
 */
struct DatabaseOffer: Equatable {
    /**
     The `id` property of an `Offer` as a Base-64 `String` of the `UUID` as bytes.
     */
    let id: String
    /**
     Corresponds to an `Offer`'s `isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to an `Offer`'s `isTaken` property.
     */
    let isTaken: Bool
    /**
     The `maker` property of an `Offer` as a `String`.
     */
    let maker: String
    /**
     The `interfaceId` property of an `Offer` as a `String`.
     */
    let interfaceId: String
    /**
     The `stablecoin` property of an `Offer` as a `String`.
     */
    let stablecoin: String
    /**
     The `amountLowerBound` property of an `Offer` as a `String`.
     */
    let amountLowerBound: String
    /**
     The `amountUpperBound` property of an `Offer` as a `String`.
     */
    let amountUpperBound: String
    /**
     The `securityDepsositAmount` property of an `Offer` as a `String`.
     */
    let securityDepositAmount: String
    /**
     The `serviceFeeRate` property of an `Offer` as a `String`.
     */
    let serviceFeeRate: String
    /**
     The `onChainDirection` property of an `Offer` as a `String`.
     */
    let onChainDirection: String
    /**
     The `protocolVersion` property of an `Offer` as a `String`.
     */
    let protocolVersion: String
    /**
     The `chainID` property of an `Offer` as a `String`.
     */
    let chainID: String
    /**
     Corresponds to an `Offer`'s `havePublicKey` property.
     */
    let havePublicKey: Bool
    /**
     Corresponds to an `Offer`'s `isUserMaker` property.
     */
    let isUserMaker: Bool
    /**
     The `state` property of an `Offer` as a `String`.
     */
    let state: String
    /**
     The `approveToOpenState` property of an `Offer` as a `String`.
     */
    let approveToOpenState: String
    /**
     The hash of the transaction that approved the token transfer in order to open this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let approveToOpenTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `approveToOpenTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let approveToOpenTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `approveToOpenTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let approveToOpenTransactionCreationBlockNumber: Int?
    /**
     The `openingOfferState` property of an `Offer` as a `String`.
     */
    let openingOfferState: String
    /**
     The hash of the transaction that opened this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let openingOfferTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `openingOfferTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let openingOfferTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `openingOfferTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let openingOfferTransactionCreationBlockNumber: Int?
    /**
     The `cancelingOfferState` property of an `Offer` as a `String`.
     */
    let cancelingOfferState: String
    /**
     The hash of the transaction that canceled this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let offerCancellationTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `offerCancellationTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let offerCancellationTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `offerCancellationTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let offerCancellationTransactionCreationBlockNumber: Int?
    /**
     The `editingOfferState` property of an `Offer` as a `String`.
     */
    let editingOfferState: String
    /**
     The hash of the most recent transaction that edited  this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let offerEditingTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `offerEditingTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let offerEditingTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `offerEditingTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let offerEditingTransactionCreationBlockNumber: Int?
    /**
     The `approveToTakeState` property of an `Offer` as a `String`.
     */
    let approveToTakeState: String
    /**
     The hash of the transaction that approved the token transfer in order to take this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let approveToTakeTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `approveToTakeTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let approveToTakeTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `approveToTakeTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let approveToTakeTransactionCreationBlockNumber: Int?
    /**
     The `takingOfferState` property of an `Offer` as a `String`.
     */
    let takingOfferState: String
    /**
     The hash of the transaction that opened this `Offer` as a hexadecimal `String`, or `nil` if no such transaction exists.
     */
    let takingOfferTransactionHash: String?
    /**
     The time at which the transaction with the hash specified by `takingOfferTransactionHash` was created by this interface in ISO 8601 format in UTC, or `nil` if no such transaction exists.
     */
    let takingOfferTransactionCreationTime: String?
    /**
     The number of the latest block at the time when the transaction with the hash specified by `takingOfferTransactionHash` was created by this interface, or `nil` if no such transaction exists.
     */
    let takingOfferTransactionCreationBlockNumber: Int?
}

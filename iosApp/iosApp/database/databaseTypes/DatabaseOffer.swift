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
}

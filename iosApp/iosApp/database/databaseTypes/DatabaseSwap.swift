//
//  DatabaseSwap.swift
//  iosApp
//
//  Created by jimmyt on 8/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

struct DatabaseSwap: Equatable {
    /**
     The `id` property of a `Swap` as a Base-64 `String` of the `UUID` as bytes.
     */
    let id: String
    /**
     Corresponds to the `Swap.isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to the `Swap.requiresFill` property.
     */
    let requiresFill: Bool
    /**
     The `maker` property of a `Swap` as a `String`.
     */
    let maker: String
    /**
     The `makerInterfaceID` property of a `Swap` as a `String`.
     */
    let makerInterfaceID: String
    /**
     The `taker` property of a `Swap` as a `String`.
     */
    let taker: String
    /**
     The `takerInterfaceID` property of a `Swap` as a `String`.
     */
    let takerInterfaceID: String
    /**
     The `stablecoin` property of a `Swap` as a `String`.
     */
    let stablecoin: String
    /**
     The `amountLowerBound` property of a `Swap` as a `String`.
     */
    let amountLowerBound: String
    /**
     The `amountUpperBound` property of a `Swap` as a `String`.
     */
    let amountUpperBound: String
    /**
     The `securityDepositAmount` property of a `Swap` as a `String`.
     */
    let securityDepositAmount: String
    /**
     The `takenSwapAmount` property of a `Swap` as a `String`.
     */
    let takenSwapAmount: String
    /**
     The `serviceFeeAmount` property of a `Swap` as a `String`.
     */
    let serviceFeeAmount: String
    /**
     The `serviceFeeRate` property of a `Swap` as a `String`.
     */
    let serviceFeeRate: String
    /**
     The `onChainDirection` property of a `Swap` as a `String`.
     */
    let onChainDirection: String
    /**
     The `onChainSettlementMethod` property of a `Swap` as a `String`.
     */
    let onChainSettlementMethod: String
    /**
     The `protocolVersion` property of a `Swap` as a `String`.
     */
    let protocolVersion: String
    /**
     Corresponds to a the `Swap.isPaymentSent` property.
     */
    let isPaymentSent: Bool
    /**
     Corresponds to a the `Swap.isPaymentReceived` property.
     */
    let isPaymentReceived: Bool
    /**
     Corresponds to a the `Swap.hasBuyerClosed` property.
     */
    let hasBuyerClosed: Bool
    /**
     Corresponds to a the `Swap.hasSellerClosed` property.
     */
    let hasSellerClosed: Bool
    /**
     The `onChainDisputeRaiser` property of a `Swap` as a `String`.
     */
    let onChainDisputeRaiser: String
    /**
     The `chainID` property of a `Swap` as a `String`.
     */
    let chainID: String
    /**
     The `state` property of a `Swap` as a `String`.
     */
    let state: String
    /**
     The `role` property of a `Swap` as a `String`.
     */
    let role: String
}

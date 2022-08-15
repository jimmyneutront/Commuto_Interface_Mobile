//
//  SwapStruct.swift
//  iosApp
//
//  Created by jimmyt on 8/14/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import web3swift

/**
 Represents an on-chain [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) struct.
 */
struct SwapStruct {
    /**
     Corresponds to an on-chain Struct's `isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to an on-chain Struct's `requiresFill` property.
     */
    let requiresFill: Bool
    /**
     Corresponds to an on-chain Struct's `maker` property.
     */
    let maker: EthereumAddress
    /**
     Corresponds to an on-chain Struct's `makerInterfaceId` property.
     */
    let makerInterfaceID: Data
    /**
     Corresponds to an on-chain Struct's `taker` property.
     */
    let taker: EthereumAddress
    /**
     Corresponds to an on-chain Struct's `takerInterfaceId` property.
     */
    let takerInterfaceID: Data
    /**
     Corresponds to an on-chain Struct's `stablecoin` property.
     */
    let stablecoin: EthereumAddress
    /**
     Corresponds to an on-chain Struct's `amountLowerBound` property.
     */
    let amountLowerBound: BigUInt
    /**
     Corresponds to an on-chain Struct's `amountUpperBound` property.
     */
    let amountUpperBound: BigUInt
    /**
     Corresponds to an on-chain Struct's `securityDepositAmount` property.
     */
    let securityDepositAmount: BigUInt
    /**
     Corresponds to an on-chain Struct's `takenSwapAmount` property.
     */
    let takenSwapAmount: BigUInt
    /**
     Corresponds to an on-chain Struct's `serviceFeeAmount` property.
     */
    let serviceFeeAmount: BigUInt
    /**
     Corresponds to an on-chain Struct's `serviceFeeRate` property.
     */
    let serviceFeeRate: BigUInt
    /**
     Corresponds to an on-chain Struct's `direction` property.
     */
    let direction: BigUInt
    /**
     Corresponds to an on-chain Struct's `settlementMethod` property.
     */
    let settlementMethod: Data
    /**
     Corresponds to an on-chain Struct's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
    /**
     Corresponds to an on-chain Struct's `isPaymentSent` property.
     */
    let isPaymentSent: Bool
    /**
     Corresponds to an on-chain Struct's `isPaymentReceived` property.
     */
    let isPaymentReceived: Bool
    /**
     Corresponds to an on-chain Struct's `hasBuyerClosed` property.
     */
    let hasBuyerClosed: Bool
    /**
     Corresponds to an on-chain Struct's `hasSellerClosed` property.
     */
    let hasSellerClosed: Bool
    /**
     Corresponds to an on-chain Struct's `disputeRaiser` property.
     */
    let disputeRaiser: BigUInt
    
    /**
     Returns an `Array` containing the properties of this struct, which can be passed to a web3swift write transaction call.
     */
    func toSwapDataArray() -> [AnyObject] {
        return [
            isCreated,
            requiresFill,
            maker,
            makerInterfaceID,
            taker,
            takerInterfaceID,
            stablecoin,
            amountLowerBound,
            amountUpperBound,
            securityDepositAmount,
            takenSwapAmount,
            serviceFeeAmount,
            serviceFeeRate,
            direction,
            settlementMethod,
            protocolVersion,
            isPaymentSent,
            isPaymentReceived,
            hasBuyerClosed,
            hasSellerClosed,
            disputeRaiser,
        ] as [AnyObject]
    }
}

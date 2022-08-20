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
     Creates a `SwapStruct` from the `[AnyObject]` obtained via a web3swift read transaction call to [getSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-swap).
     
     - Parameters:
        - response: The `[AnyObject]` obtained by a read transaction call to getSwap.
        - chainID: The ID of the blockchain from which `response` was obtained.
     
     - Returns: A new `SwapStruct` with property values derived from `response` and `chainID`, or `nil` if `response`'s `isCreated` property is `false`.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if an expected parameter in `response` is missing.
     */
    static func createFromGetSwapResponse(response: [AnyObject], chainID: BigUInt) throws -> SwapStruct? {
        guard let isCreated: Bool = response[0] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "isCreated"))
        }
        if !isCreated {
            return nil
        }
        guard let requiresFill = response[1] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "requiresFill"))
        }
        guard let maker = response[2] as? EthereumAddress else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "maker"))
        }
        guard let makerInterfaceID = response[3] as? Data else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "makerInterfaceID"))
        }
        guard let taker = response[4] as? EthereumAddress else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "taker"))
        }
        guard let takerInterfaceID = response[5] as? Data else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "takerInterfaceID"))
        }
        guard let stablecoin = response[6] as? EthereumAddress else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "stablecoin"))
        }
        guard let amountLowerBound = response[7] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "amountLowerBound"))
        }
        guard let amountUpperBound = response[8] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "taker"))
        }
        guard let securityDepositAmount = response[9] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "securityDepositAmount"))
        }
        guard let takenSwapAmount = response[10] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "takenSwapAmount"))
        }
        guard let serviceFeeAmount = response[11] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "serviceFeeAmount"))
        }
        guard let serviceFeeRate = response[12] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "serviceFeeRate"))
        }
        guard let direction = response[13] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "direction"))
        }
        guard let settlementMethod = response[14] as? Data else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "settlementMethod"))
        }
        guard let protocolVersion = response[15] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "protocolVersion"))
        }
        guard let isPaymentSent = response[16] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "isPaymentSent"))
        }
        guard let isPaymentReceived = response[17] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "isPaymentReceived"))
        }
        guard let hasBuyerClosed = response[18] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "hasBuyerClosed"))
        }
        guard let hasSellerClosed = response[19] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "hasSellerClosed"))
        }
        guard let disputeRaiser = response[20] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "disputeRaiser"))
        }
        return SwapStruct(isCreated: isCreated, requiresFill: requiresFill, maker: maker, makerInterfaceID: makerInterfaceID, taker: taker, takerInterfaceID: takerInterfaceID, stablecoin: stablecoin, amountLowerBound: amountLowerBound, amountUpperBound: amountUpperBound, securityDepositAmount: securityDepositAmount, takenSwapAmount: takenSwapAmount, serviceFeeAmount: serviceFeeAmount, serviceFeeRate: serviceFeeRate, direction: direction, settlementMethod: settlementMethod, protocolVersion: protocolVersion, isPaymentSent: isPaymentSent, isPaymentReceived: isPaymentReceived, hasBuyerClosed: hasBuyerClosed, hasSellerClosed: hasSellerClosed, disputeRaiser: disputeRaiser)
    }
    
    /**
     Called by `createFromGetSwapResponse` to get the appropriate message for a `BlockchainService.unexpectedNilError` when `createFromGetSwapResponse` is unable to get the value of a field that is expected in its `response` parameter.
     */
    private static func makeCreationErrorMessage(valueName: String) -> String {
        return "Got nil while getting \(valueName) value from getSwap response"
    }
    
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

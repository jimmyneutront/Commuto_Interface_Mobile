//
//  OfferStruct.swift
//  iosApp
//
//  Created by jimmyt on 6/24/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 Represents an on-chain [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) struct.
 */
struct OfferStruct {
    /**
     Corresponds to an on-chain Offer's `isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to an on-chain Offer's `isTaken` property.
     */
    let isTaken: Bool
    /**
     Corresponds to an on-chain Offer's `maker` property.
     */
    let maker: EthereumAddress
    /**
     Corresponds to an on-chain Offer's `interfaceId` property.
     */
    let interfaceId: Data
    /**
     Corresponds to an on-chain Offer's `stablecoin` property.
     */
    let stablecoin: EthereumAddress
    /**
     Corresponds to an on-chain Offer's `amountLowerBound` property.
     */
    let amountLowerBound: BigUInt
    /**
     Corresponds to an on-chain Offer's `amountUpperBound` property.
     */
    let amountUpperBound: BigUInt
    /**
     Corresponds to an on-chain Offer's `securityDepositAmount` property.
     */
    let securityDepositAmount: BigUInt
    /**
     Corresponds to an on-chain Offer's `serviceFeeRate` property.
     */
    let serviceFeeRate: BigUInt
    /**
     Corresponds to an on-chain Offer's `direction` property.
     */
    let direction: BigUInt
    /**
     Corresponds to an on-chain Offer's `settlementMethods` property.
     */
    let settlementMethods: [Data]
    /**
     Corresponds to an on-chain Offer's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
    /**
     The ID of the blockchain on which this Offer exists.
     */
    let chainID: BigUInt
    
    /**
     Creates an `OfferStruct` from the `[AnyObject]` obtained via a web3swift read transaction call to [getOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-offer).
     
     - Parameters:
        - response: The `[AnyObject]` obtained by a read transaction call to getOffer.
        - chainID: The ID of the blockchain from which `response` was obtained.
     
     - Returns: A new `OfferStruct` with property values derived from `response` and `chainID`.
     
     - Throws: `BlockchainServiceError.unexpectedNilError` if an expected parameter in `response` is missing.
     */
    static func createFromGetOfferResponse(response: [AnyObject], chainID: BigUInt) throws -> OfferStruct {
        guard let isCreated = response[0] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "isCreated"))
        }
        guard let isTaken: Bool = response[1] as? Bool else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "isTaken"))
        }
        guard let maker = response[2] as? EthereumAddress else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "maker"))
        }
        guard let interfaceId: Data = response[3] as? Data else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "interfaceId"))
        }
        guard let stablecoin = response[4] as? EthereumAddress else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "stablecoin"))
        }
        guard let amountLowerBound = response[5] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "amountLowerBound"))
        }
        guard let amountUpperBound = response[6] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "amountUpperBound"))
        }
        guard let securityDepositAmount = response[7] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "securityDepositAmount"))
        }
        guard let serviceFeeRate = response[8] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "serviceFeeRate"))
        }
        guard let direction = response[9] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "direction"))
        }
        guard let settlementMethods: [Data] = response[10] as? [Data] else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "settlementMethods"))
        }
        guard let protocolVersion = response[11] as? BigUInt else {
            throw BlockchainServiceError.unexpectedNilError(desc: makeCreationErrorMessage(valueName: "protocolVersion"))
        }
        return OfferStruct(isCreated: isCreated, isTaken: isTaken, maker: maker, interfaceId: interfaceId, stablecoin: stablecoin, amountLowerBound: amountLowerBound, amountUpperBound: amountUpperBound, securityDepositAmount: securityDepositAmount, serviceFeeRate: serviceFeeRate, direction: direction, settlementMethods: settlementMethods, protocolVersion: protocolVersion, chainID: chainID)
    }
    
    /**
     Called by `createFromGetOfferResponse` to get the appropriate message for a `BlockchainService.unexpectedNilError` when `createFromGetOfferResponse` is unable to get the value of a field that is expected in its `response` parameter.
     */
    private static func makeCreationErrorMessage(valueName: String) -> String {
        return "Got nil while getting " + valueName + " value from getOffer response"
    }
    
}

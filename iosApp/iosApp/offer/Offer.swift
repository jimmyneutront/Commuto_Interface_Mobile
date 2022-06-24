//
//  Offer.swift
//  iosApp
//
//  Created by jimmyt on 5/29/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import web3swift

/**
 Represents an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
 */
struct Offer {
    /**
     The ID that uniquely identifies the offer, as a `UUID`.
     */
    var id: UUID
    /**
     The direction of the offer, indicating whether the maker is offering to buy stablecoin or sell stablecoin.
     */
    var direction: String
    /**
     The price at which the maker is offering to buy/sell stablecoin, as the cost in FIAT per one STBL.
     */
    var price: String
    /**
     A string of the form "FIAT/STBL", where FIAT is the abbreviation of the fiat currency being exchanged, and STBL is the ticker symbol of the stablecoin being exchanged.
     */
    var pair: String
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
    let onChainDirection: BigUInt
    /**
     Corresponds to an on-chain Offer's `price` property.
     */
    let onChainPrice: Data
    /**
     Corresponds to an on-chain Offer's `settlementMethods` property.
     */
    let settlementMethods: [Data]
    /**
     Corresponds to an on-chain Offer's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
}

/**
 Contains a list of sample offer IDs (as `UUID`s) and a dictionary mapping those `UUID`s to `Offer`s. Used for previewing offer-related `View`s.
 */
extension Offer {
    /**
     A list of `UUID`s used for previewing offer-related `View`s
     */
    static let sampleOfferIds = [
        UUID(),
        UUID(),
        UUID()
    ]
    /**
     A dictionary mapping the contents of `sampleOfferIds` to `Offer`s. Used for previewing offer-related `View`s.
     */
    static let sampleOffers: [UUID: Offer] = [
        sampleOfferIds[0]: Offer(
            id: sampleOfferIds[0],
            direction: "Buy",
            price: "1.004",
            pair: "USD/UST",
            isCreated: true,
            isTaken: false,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainPrice: Data(),
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero
        ),
        sampleOfferIds[1]: Offer(
            id: sampleOfferIds[1],
            direction: "Buy",
            price: "1.004",
            pair: "USD/UST",
            isCreated: true,
            isTaken: false,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainPrice: Data(),
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero
        ),
        sampleOfferIds[2]: Offer(
            id: sampleOfferIds[2],
            direction: "Buy",
            price: "1.004",
            pair: "USD/UST",
            isCreated: true,
            isTaken: false,
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            onChainPrice: Data(),
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero
        ),
    ]
}

/**
 Allows the creation of a `UUID` from raw bytes as `Data`. Used to create offer IDs as `UUID`s from the raw bytes retrieved from [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) calls.
 */
extension UUID {
    /**
     Attempts to create a UUID given raw bytes as `Data`.
     
     - Parameter data: The UUID as `Data?`.
     
     - Returns: A `UUID` if one could be successfully created from the given `Data?`, or `nil` otherwise.
     */
    static func from(data: Data?) -> UUID? {
        guard data?.count == MemoryLayout<uuid_t>.size else {
            return nil
        }
        return data?.withUnsafeBytes{
            guard let baseAddress = $0.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }
            return NSUUID(uuidBytes: baseAddress) as UUID
        }
    }
    
    /**
     Returns the `UUID` as `Data`.
     */
    func asData() -> Data {
        return Data(fromArray: [
            self.uuid.0,
            self.uuid.1,
            self.uuid.2,
            self.uuid.3,
            self.uuid.4,
            self.uuid.5,
            self.uuid.6,
            self.uuid.7,
            self.uuid.8,
            self.uuid.9,
            self.uuid.10,
            self.uuid.11,
            self.uuid.12,
            self.uuid.13,
            self.uuid.14,
            self.uuid.15
        ])
    }
}

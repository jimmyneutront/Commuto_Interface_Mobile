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
class Offer: ObservableObject {
    /**
     Corresponds to an on-chain Offer's `isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to an on-chain Offer's `isTaken` property.
     */
    let isTaken: Bool
    /**
     The ID that uniquely identifies the offer, as a `UUID`.
     */
    let id: UUID
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
     The direction of the offer, indicating whether the maker is offering to buy stablecoin or sell stablecoin.
     */
    var direction: OfferDirection
    /**
     Corresponds to an on-chain Offer's `settlementMethods` property.
     */
    @Published var settlementMethods: [Data]
    /**
     Corresponds to an on-chain Offer's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
    /**
     The ID of the blockchain on which this Offer exists.
     */
    let chainID: BigUInt
    
    init?(
        isCreated: Bool,
        isTaken: Bool,
        id: UUID,
        maker: EthereumAddress,
        interfaceId: Data,
        stablecoin: EthereumAddress,
        amountLowerBound: BigUInt,
        amountUpperBound: BigUInt,
        securityDepositAmount: BigUInt,
        serviceFeeRate: BigUInt,
        onChainDirection: BigUInt,
        settlementMethods: [Data],
        protocolVersion: BigUInt,
        chainID: BigUInt
    ) {
        self.isCreated = isCreated
        self.isTaken = isTaken
        self.id = id
        self.maker = maker
        self.interfaceId = interfaceId
        self.stablecoin = stablecoin
        self.amountLowerBound = amountLowerBound
        self.amountUpperBound = amountUpperBound
        self.securityDepositAmount = securityDepositAmount
        self.serviceFeeRate = serviceFeeRate
        self.onChainDirection = onChainDirection
        if self.onChainDirection == BigUInt.zero {
            self.direction = .buy
        } else if self.onChainDirection == BigUInt.init(UInt64(1)) {
            self.direction = .sell
        } else {
            return nil
        }
        self.settlementMethods = settlementMethods
        self.protocolVersion = protocolVersion
        self.chainID = chainID
    }
    
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
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[0],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.zero,
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt.zero
        )!,
        sampleOfferIds[1]: Offer(
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[1],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.init(UInt64(1)),
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt.zero
        )!,
        sampleOfferIds[2]: Offer(
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[2],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            amountLowerBound: BigUInt.zero,
            amountUpperBound: BigUInt.zero,
            securityDepositAmount: BigUInt.zero,
            serviceFeeRate: BigUInt.zero,
            onChainDirection: BigUInt.init(UInt64(1)),
            settlementMethods: [Data()],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt.zero
        )!,
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

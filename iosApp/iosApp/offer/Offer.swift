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
     The minimum service fee for the new offer.
     */
    let serviceFeeAmountLowerBound: BigUInt
    /**
     The maximum service fee for the new offer.
     */
    let serviceFeeAmountUpperBound: BigUInt
    /**
     Corresponds to an on-chain Offer's `direction` property.
     */
    let onChainDirection: BigUInt
    /**
     The direction of the offer, indicating whether the maker is offering to buy stablecoin or sell stablecoin.
     */
    let direction: OfferDirection
    /**
     Corresponds to an on-chain Offer's `settlementMethods` property.
     */
    let onChainSettlementMethods: [Data]
    #warning("TODO: every time this is changed, settlementMethods should be re-deserialized from the new values")
    /**
     An `Array` of `SettlementMethod`s derived from parsing `onChainSettlementMethods`.
     */
    @Published var settlementMethods: [SettlementMethod]
    /**
     Corresponds to an on-chain Offer's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
    /**
     The ID of the blockchain on which this Offer exists.
     */
    let chainID: BigUInt
    /**
     Indicates whether this interface has a copy of the public key specified by the `interfaceId` field
     */
    var havePublicKey: Bool
    /**
     Indicates whether the user of this interface is the maker of this offer.
     */
    var isUserMaker: Bool
    /**
     Indicates the current state of this offer, as described in the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     */
    var state: OfferState
    /**
     If this offer was made by the user of the interface, this indicates whether the offer is being canceled, and if so, what part of the offer cancellation process it is in. If this offer was not made by the user of this interface, this property is not used.
     */
    @Published var cancelingOfferState = CancelingOfferState.none
    /**
     (This property is used only if the maker of this offer is the user of this interface.) The `Error` that occurred during the offer cancellation process, or `nil` if no such error has occurred.
     */
    var cancelingOfferError: Error? = nil
    /**
    (This property is used only if the maker of this offer is the user of this interface.) The new `SettlementMethod`s with which the user wants to replace the offer's current settlement methods by editing the offer. If the user is not currently editing this offer, (or if the user is not the maker of this offer) this array should be empty.
     */
    @Published var selectedSettlementMethods: [SettlementMethod] = []
    /**
     If this offer was made by the user of the interface, this indicates whether the offer is being edited, and if so, what part of the offer editing process it is in. If this offer was not made by the user of this interface, this property is not used.
     */
    @Published var editingOfferState = EditingOfferState.none
    /**
     (This property is used only if the maker of this offer is the user of this interface.) The `Error` that occurred during the offer editing process, or `nil` if no such error has occurred.
     */
    var editingOfferError: Error? = nil
    
    /**
     Creates an `Offer` using data obtained from a call to [getOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#get-offer).
     
     - Parameters:
        - isCreated: Corresponds to an `OfferStruct`'s `isCreated` property.
        - isTaken: Corresponds to an `OfferStruct`'s `isCreated` property.
        - id: The ID of this offer, as a `UUID`.
        - maker: The offer maker's blockchain address.
        - interfaceId: The offer maker's interface ID.
        - stablecoin: The contract address of the offer's stablecoin.
        - amountLowerBound: Corresponds to an `OfferStruct`'s `amountLowerBound` property.
        - amountUpperBound: Corresponds to an `OfferStruct`'s `amountUpperBound` property.
        - securityDepositAmount: Corresponds to an `OfferStruct`'s `securityDepositAmount` property.
        - serviceFeeRate: Corresponds to an `OfferStruct`'s `serviceFeeRate` property.
        - onChainDirection: Corresponds to an `OfferStruct`'s `direction` property.
        - onChainSettlementMethods: Corresponds to an `OfferStruct`'s `settlementMethods` property.
        - protocolVersion: Corresponds to an `OfferStruct`'s `protocolVersion` property.
        - chainID: Corresponds to an `OfferStruct`'s `chainID` property.
        - havePublicKey: Indicates whether this interface has, in persistent storage, the public key specified by the `interfaceId` parameter.
        - isUserMaker: Indicates whether the user of this interface is the maker of this offer.
        - state: Indicates the current state of this offer.
     */
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
        onChainSettlementMethods: [Data],
        protocolVersion: BigUInt,
        chainID: BigUInt,
        havePublicKey: Bool,
        isUserMaker: Bool,
        state: OfferState
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
        self.serviceFeeAmountLowerBound = serviceFeeRate * (amountLowerBound / BigUInt(10_000))
        self.serviceFeeAmountUpperBound = serviceFeeRate * (amountUpperBound / BigUInt(10_000))
        self.onChainDirection = onChainDirection
        if self.onChainDirection == BigUInt.zero {
            self.direction = .buy
        } else if self.onChainDirection == BigUInt.init(UInt64(1)) {
            self.direction = .sell
        } else {
            return nil
        }
        self.onChainSettlementMethods = onChainSettlementMethods
        self.settlementMethods = onChainSettlementMethods.compactMap { onChainSettlementMethod in
            return try? JSONDecoder().decode(SettlementMethod.self, from: onChainSettlementMethod)
        }
        self.protocolVersion = protocolVersion
        self.chainID = chainID
        self.havePublicKey = havePublicKey
        self.isUserMaker = isUserMaker
        self.state = state
    }
    
    /**
     Creates a new `Offer`.
     
     - Parameters:
        - isCreated: Indicates whether this offer currently exists on-chain.
        - isTaken: Indicates whether this offer has been taken.
        - id: The ID of this offer, as a `UUID`.
        - maker: The offer maker's blockchain address.
        - interfaceID: The offer maker's interface ID.
        - stablecoin: The contract address of the offer's stablecoin.
        - amountLowerBound: The minimum amount of stablecoin that the offer maker is willing to exchange.
        - amountUpperBound: The maximum amount of stablecoin that the offer maker is willing to exchange.
        - securityDepositAmount: The amount of stablecoin that the offer maker is locking in escrow as a security deposit, and the amount of stablecoin that one must lock up in escrow in order to take this offer.
        - serviceFeeRate: The percentage of the amount of stablecoin exchanged that the offer maker and taker must pay as a service fee,
        - direction: The direction of the offer, either `buy` or `sell`.
        - settlementMethods: The settlement methods by which the maker of the offer is willing to accept payment.
        - protocolVersion: Indicates the minimum Commuto Interface version that one must have in order to take this offer.
        - chainID: The ID of the blockchain on which this offer exists.
        - havePublicKey: Indicates whether this interface has, in persistent storage, the public key specified by the `interfaceID` parameter.
        - isUserMaker: Indicates whether the user of this interface is the maker of this offer.
        - state: Indicates the current state of this offer.
     */
    init(
        isCreated: Bool,
        isTaken: Bool,
        id: UUID,
        maker: EthereumAddress,
        interfaceID: Data,
        stablecoin: EthereumAddress,
        amountLowerBound: BigUInt,
        amountUpperBound: BigUInt,
        securityDepositAmount: BigUInt,
        serviceFeeRate: BigUInt,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod],
        protocolVersion: BigUInt,
        chainID: BigUInt,
        havePublicKey: Bool,
        isUserMaker: Bool,
        state: OfferState
    ) {
        self.isCreated = isCreated
        self.isTaken = isTaken
        self.id = id
        self.maker = maker
        self.interfaceId = interfaceID
        self.stablecoin = stablecoin
        self.amountLowerBound = amountLowerBound
        self.amountUpperBound = amountUpperBound
        self.securityDepositAmount = securityDepositAmount
        self.serviceFeeRate = serviceFeeRate
        self.serviceFeeAmountLowerBound = serviceFeeRate * (amountLowerBound / BigUInt(10_000))
        self.serviceFeeAmountUpperBound = serviceFeeRate * (amountUpperBound / BigUInt(10_000))
        self.onChainDirection = {
            switch direction {
            case .buy:
                return BigUInt(0)
            case .sell:
                return BigUInt(1)
            }
        }()
        self.direction = direction
        self.onChainSettlementMethods = settlementMethods.compactMap { settlementMethod in
            return try? JSONEncoder().encode(settlementMethod)
        }
        self.settlementMethods = settlementMethods
        self.protocolVersion = protocolVersion
        self.chainID = chainID
        self.havePublicKey = havePublicKey
        self.isUserMaker = isUserMaker
        self.state = state
    }
    
    /**
     Creates an `OfferStruct` derived from this `Offer`.
     
     - Returns: An `OfferStruct` derived from this `Offer`.
     */
    func toOfferStruct() -> OfferStruct {
        return OfferStruct(
            isCreated: self.isCreated,
            isTaken: self.isTaken,
            maker: self.maker,
            interfaceId: self.interfaceId,
            stablecoin: self.stablecoin,
            amountLowerBound: self.amountLowerBound,
            amountUpperBound: self.amountUpperBound,
            securityDepositAmount: self.securityDepositAmount,
            serviceFeeRate: self.serviceFeeRate,
            direction: self.onChainDirection,
            settlementMethods: self.onChainSettlementMethods,
            protocolVersion: self.protocolVersion,
            chainID: self.chainID
        )
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
        UUID(),
        UUID(),
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
            stablecoin: EthereumAddress("0x663F3ad617193148711d28f5334eE4Ed07016602")!, // DAI on Hardhat
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 1_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            onChainDirection: BigUInt.zero,
            onChainSettlementMethods: [
                """
                {
                    "f": "EUR",
                    "p": "0.94",
                    "m": "SEPA"
                }
                """.data(using: .utf8)!,
            ],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID
            havePublicKey: false,
            isUserMaker: true,
            state: .offerOpened
        )!,
        sampleOfferIds[1]: Offer(
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[1],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x2E983A1Ba5e8b38AAAeC4B440B9dDcFBf72E15d1")!, // USDC on Hardhat
            amountLowerBound: 10_000 * BigUInt(10).power(6),
            amountUpperBound: 20_000 * BigUInt(10).power(6),
            securityDepositAmount: 1_000 * BigUInt(10).power(6),
            serviceFeeRate: BigUInt(10),
            onChainDirection: BigUInt.init(UInt64(1)),
            onChainSettlementMethods: [
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            ],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID
            havePublicKey: false,
            isUserMaker: true,
            state: .offerOpened
        )!,
        sampleOfferIds[2]: Offer(
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[2],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x8438Ad1C834623CfF278AB6829a248E37C2D7E3f")!, // BUSD on Hardhat
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 10_000 * BigUInt(10).power(18),
            securityDepositAmount: 1_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(1),
            onChainDirection: BigUInt.init(UInt64(1)),
            onChainSettlementMethods: [
                """
                {
                    "f": "BUSD",
                    "p": "1.00",
                    "m": "SANDDOLLAR"
                }
                """.data(using: .utf8)!,
            ],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID
            havePublicKey: false,
            isUserMaker: false,
            state: .offerOpened
        )!,
        sampleOfferIds[3]: Offer(
            isCreated: true,
            isTaken: false,
            id: sampleOfferIds[3],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            interfaceId: Data(),
            stablecoin: EthereumAddress("0x1F98431c8aD98523631AE4a59f267346ea31F984")!, // UniswapV3Factory on Ethereum Mainnet, definitely not a stablecoin contract
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 10_000 * BigUInt(10).power(18),
            securityDepositAmount: 1_000 * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            onChainDirection: BigUInt.init(UInt64(1)),
            onChainSettlementMethods: [],
            protocolVersion: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID
            havePublicKey: false,
            isUserMaker: false,
            state: .offerOpened
        )!,
    ]
}

#warning("TODO: move this to extension group")
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

//
//  Swap.swift
//  iosApp
//
//  Created by jimmyt on 8/9/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Combine
import Foundation
import web3swift

/**
 Represents a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
 */
class Swap: ObservableObject {
    /**
     Corresponds to an on-chain Swap's `isCreated` property.
     */
    let isCreated: Bool
    /**
     Corresponds to an on-chain Swap's `requiresFill` property.
     */
    var requiresFill: Bool
    /**
     The ID that uniquely identifies this swap, as a `UUID`.
     */
    let id: UUID
    /**
     Corresponds to an on-chain Swap's `maker` property.
     */
    let maker: EthereumAddress
    /**
     Corresponds to an on-chain Swap's `makerInterfaceId` property.
     */
    let makerInterfaceID: Data
    /**
     Corresponds to an on-chain Swap's `taker` property.
     */
    let taker: EthereumAddress
    /**
     Corresponds to an on-chain Swap's `takerInterfaceId` property.
     */
    let takerInterfaceID: Data
    /**
     Corresponds to an on-chain Swap's `stablecoin` property.
     */
    let stablecoin: EthereumAddress
    /**
     Corresponds to an on-chain Swap's `amountLowerBound` property.
     */
    let amountLowerBound: BigUInt
    /**
     Corresponds to an on-chain Swap's `amountUpperBound` property.
     */
    let amountUpperBound: BigUInt
    /**
     Corresponds to an on-chain Swap's `securityDepositAmount` property.
     */
    let securityDepositAmount: BigUInt
    /**
     Corresponds to an on-chain Swap's `takenSwapAmount` property.
     */
    let takenSwapAmount: BigUInt
    /**
     Corresponds to an on-chain Swap's `serviceFeeAmount` property.
     */
    let serviceFeeAmount: BigUInt
    /**
     Corresponds to an on-chain Swap's `serviceFeeRate` property.
     */
    let serviceFeeRate: BigUInt
    /**
     Corresponds to an on-chain Swap's `direction` property.
     */
    let onChainDirection: BigUInt
    /**
     The direction of the swap, indicating whether the maker is buying stablecoin or selling stablecoin.
     */
    let direction: OfferDirection
    /**
     Corresponds to an on-chain Swap's `settlementMethod` property.
     */
    let onChainSettlementMethod: Data
    /**
     A `SettlementMethod` derived by deserializing `onChainSettlementMethod`, selected by the taker from the list of settlement method specified by the maker, by which the maker and taker will send/receive traditional currency payment.
     */
    var settlementMethod: SettlementMethod
    /**
     Corresponds to an on-chain Swap's `protocolVersion` property.
     */
    let protocolVersion: BigUInt
    /**
     Corresponds to an on-chain Swap's `isPaymentSent` property.
     */
    var isPaymentSent: Bool
    /**
     Corresponds to an on-chain Swap's `isPaymentReceived` property.
     */
    var isPaymentReceived: Bool
    /**
     Corresponds to an on-chain Swap's `hasBuyerClosed` property.
     */
    var hasBuyerClosed: Bool
    /**
     Corresponds to an on-chain Swap's `hasSellerClosed` property.
     */
    var hasSellerClosed: Bool
    /**
     Corresponds to an on-chain Swap's `disputeRaiser` property.
     */
    let onChainDisputeRaiser: BigUInt
    /**
     The ID of the blockchain on which this Swap exists.
     */
    let chainID: BigUInt
    /**
     Indicates the current state of this swap, as described in the [Commuto Interface Specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     */
    @Published var state: SwapState
    /**
     Indicates the interface user's role for this swap.
     */
    let role: SwapRole
    /**
     If this swap is a maker-and-seller swap and was made by the user of this interface, this indicates whether a token transfer is being approved in order to fill the swap, and if so, what part of the token transfer approval process it is in. Otherwise, this property is not used.
     */
    @Published var approvingToFillState = TokenTransferApprovalState.none
    /**
     (This property is used only if this swap is a maker-and-seller swap and was made by the user of this interface.) The `Error` that occured during the token transfer approval process in order to fill the swap, or `nil` if no such error has occured.
     */
    var approvingToFillError: Error? = nil
    /**
     (This property is used only if this swap is a maker-and-seller swap and was made by the user of this interface.) The `BlockchainTransaction` that has approved a token transfer in order to fill this swap. Note that this transaction may be: not yet sent to a blockchain node, pending, confirmed and successful, confirmed and failed, or dropped.
     */
    var approvingToFillTransaction: BlockchainTransaction? = nil
    /**
     (This property is used only if this swap is a maker-and-seller swap and was made by the user of this interface.) This indicates whether we are currently filling this swap, and if so, what part of the swap filling process we are in.
     */
    @Published var fillingSwapState = FillingSwapState.none
    /**
     (This property is used only if this swap is a maker-and-seller swap and was made by the user of this interface.) The `Error` that we encountered during the swap filling process, or `nil` of no such error has occurred.
     */
    var fillingSwapError: Error? = nil
    /**
     The `BlockchainTransaction` that called [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) in order to fill this swap. Note that this transaction may be: not yet sent to a blockchain node, pending, confirmed and successful, confirmed and failed, or dropped.
     */
    var swapFillingTransaction: BlockchainTransaction? = nil
    /**
     (This property is used only if the user of this interface is the buyer in this swap.) This indicates whether we are currently reporting that we have sent fiat payment to the seller in this swap by calling [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent), and if so, what part of the payment-sent-reporting process we are in.
     */
    @Published var reportingPaymentSentState = ReportingPaymentSentState.none
    /**
     (This property is used only if the user of this interface is the buyer in this swap.) The `Error` that we encountered during the reporting-payment-sent process, or `nil` if no such error has occurred.
     */
    var reportingPaymentSentError: Error? = nil
    /**
     The `BlockchainTransaction` that called [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for this swap. If the user of this interface is not the buyer, all properties of this `BlockchainTransaction` except the transaction hash may not be accurate.
     */
    var reportPaymentSentTransaction: BlockchainTransaction? = nil
    /**
     (This property is used only if the user of this interface is the seller in this swap.) This indicates whether we are currently reporting that we have received fiat payment from the buyer in this swap by calling [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received), and if so, what part of the payment-received-reporting process we are in.
     */
    @Published var reportingPaymentReceivedState = ReportingPaymentReceivedState.none
    /**
     (This property is used only if the user of this interface is the seller in this swap.) The `Error` that we encountered during the reporting-payment-received process, or `nil` if no such error has occurred.
     */
    var reportingPaymentReceivedError: Error? = nil
    /**
     The `BlockchainTransaction` that called [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for this swap. If the user of this interface is not the seller, all properties of this `BlockchainTransaction` except the transaction hash may not be accurate.
     */
    var reportPaymentReceivedTransaction: BlockchainTransaction? = nil
    /**
     This indicates whether we are currently closing this swap by calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap), and if so, what part of the swap-closing process we are in.
     */
    @Published var closingSwapState = ClosingSwapState.none
    /**
     The `Error` that we encountered during the swap closing process, or `nil` if no such error has occured.
     */
    var closingSwapError: Error? = nil
    /**
     The `BlockchainTransaction` (signed by the user of this interface) that called [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for this swap.
     */
    var closeSwapTransaction: BlockchainTransaction? = nil
    /**
     The private settlement method data belonging to the maker of this swap for this swap's settlement method, or `nil` if such data does not exist.
     */
    var makerPrivateSettlementMethodData: String? = nil
    /**
     The private settlement method data belonging to the taker of this swap for this swap's settlement method, or `nil` if such data does not exist.
     */
    var takerPrivateSettlementMethodData: String? = nil
    
    
    /**
     Creates a new `Swap`.
     
     - Parameters:
        - isCreated: Indicates whether this swap currently exists on-chain.
        - requiresFill: Indicates whether this is a maker-as-seller trade and, if so, whether the maker has deposited the taken swap amount into the CommutoSwap contract (i.e. the swap is filled)
        - id: The ID of this swap, as a `UUID`.
        - maker: The swap maker's blockchain address.
        - makerInterfaceID: The swap maker's interface ID.
        - taker: The swap taker's blockchain address.
        - takerInterfaceID: The swap taker's interface ID.
        - stablecoin: The contract address of the swap's stablecoin.
        - amountLowerBound: The value of the corresponding Offer's `amountLowerBound` property.
        - amountUpperBound: The value of the corresponding Offer's `amountUpperBound` property.
        - securityDepositAmount: The amount of stablecoin that the maker and taker must lock up in escrow during this swap.
        - serviceFeeRate: The percentage times 100 of `takenSwapAmount` that the swap maker and taker must pay as a service fee.
        - direction: The direction of the swap, either `buy` or `sell`.
        - onChainSettlementMethod: The settlement method selected by the taker, as serialized by the maker of the corresponding offer.
        - protocolVersion: Indicates the minimum Commuto Interface version that one must have in order to take this offer.
        - isPaymentSent: Indicates whether the buyer has sent traditional currency payment for this Swap.
        - isPaymentReceived: Indicates whether the seller has received traditional currency payment for this Swap.
        - hasBuyerClosed: Indicates whether the buyer has claimed their purchased stablecoin and reclaimed their security deposit (and the unspent service fee, if any, if they are the maker).
        - hasSellerClosed: Indicates whether the seller has reclaimed their security deposit (and the unspent service fee, if any, if they are the maker)
        - onChainDisputeRaiser: Corresponds to an on-chain Swap's raw value.
        - chainID: The ID of the blockchain on which this swap exists.
        - state: Indicates the current state of this swap.
        - role: Indicates the interface user's role for this swap.
     */
    init(
        isCreated: Bool,
        requiresFill: Bool,
        id: UUID,
        maker: EthereumAddress,
        makerInterfaceID: Data,
        taker: EthereumAddress,
        takerInterfaceID: Data,
        stablecoin: EthereumAddress,
        amountLowerBound: BigUInt,
        amountUpperBound: BigUInt,
        securityDepositAmount: BigUInt,
        takenSwapAmount: BigUInt,
        serviceFeeAmount: BigUInt,
        serviceFeeRate: BigUInt,
        direction: OfferDirection,
        onChainSettlementMethod: Data,
        protocolVersion: BigUInt,
        isPaymentSent: Bool,
        isPaymentReceived: Bool,
        hasBuyerClosed: Bool,
        hasSellerClosed: Bool,
        onChainDisputeRaiser: BigUInt,
        chainID: BigUInt,
        state: SwapState,
        role: SwapRole
    ) throws {
        self.isCreated = isCreated
        self.requiresFill = requiresFill
        self.id = id
        self.maker = maker
        self.makerInterfaceID = makerInterfaceID
        self.taker = taker
        self.takerInterfaceID = takerInterfaceID
        self.stablecoin = stablecoin
        self.amountLowerBound = amountLowerBound
        self.amountUpperBound = amountUpperBound
        self.securityDepositAmount = securityDepositAmount
        self.takenSwapAmount = takenSwapAmount
        self.serviceFeeAmount = serviceFeeAmount
        self.serviceFeeRate = serviceFeeRate
        self.onChainDirection = direction.onChainValue
        self.direction = direction
        self.onChainSettlementMethod = onChainSettlementMethod
        self.settlementMethod = try JSONDecoder().decode(SettlementMethod.self, from: onChainSettlementMethod)
        self.protocolVersion = protocolVersion
        self.isPaymentSent = isPaymentSent
        self.isPaymentReceived = isPaymentReceived
        self.hasBuyerClosed = hasBuyerClosed
        self.hasSellerClosed = hasSellerClosed
        self.onChainDisputeRaiser = onChainDisputeRaiser
        self.chainID = chainID
        self.state = state
        self.role = role
    }
    
    /**
     Creates an `SwapStruct` derived from this `Swap`.
     
     - Returns: A `SwapStruct` derived from this `Swap`.
     */
    func toSwapStruct() -> SwapStruct {
        return SwapStruct(
            isCreated: self.isCreated,
            requiresFill: self.requiresFill,
            maker: self.maker,
            makerInterfaceID: self.makerInterfaceID,
            taker: self.taker,
            takerInterfaceID: self.takerInterfaceID,
            stablecoin: self.stablecoin,
            amountLowerBound: self.amountLowerBound,
            amountUpperBound: self.amountUpperBound,
            securityDepositAmount: self.securityDepositAmount,
            takenSwapAmount: self.takenSwapAmount,
            serviceFeeAmount: self.serviceFeeAmount,
            serviceFeeRate: self.serviceFeeRate,
            direction: self.onChainDirection,
            settlementMethod: self.onChainSettlementMethod,
            protocolVersion: self.protocolVersion,
            isPaymentSent: self.isPaymentSent,
            isPaymentReceived: self.isPaymentReceived,
            hasBuyerClosed: self.hasBuyerClosed,
            hasSellerClosed: self.hasSellerClosed,
            disputeRaiser: self.onChainDisputeRaiser
        )
    }
    
}

/**
 Contains a list of sample swap IDs (as `UUID`x) and a dictionary mapping those `UUID`s to `Swap`s. Used for previewing swap-related `View`s.
 */
extension Swap {
    /**
     A list of `UUID`s used for previewing swap-related `View`s
     */
    static let sampleSwapIds = [
        UUID(),
        UUID(),
    ]
    /**
     A dictionary mapping the contents of `sampleSwapIds` to `Swap`s. Used for previewing swap-related `View`s.
     */
    static let sampleSwaps: [UUID: Swap] = [
        sampleSwapIds[0]: try! Swap(
            isCreated: true,
            requiresFill: false,
            id: sampleSwapIds[0],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x663F3ad617193148711d28f5334eE4Ed07016602")!, // DAI on Hardhat,
            amountLowerBound: 10_000 * BigUInt(10).power(18),
            amountUpperBound: 20_000 * BigUInt(10).power(18),
            securityDepositAmount: 2_000 * BigUInt(10).power(18),
            takenSwapAmount: 15_000 * BigUInt(10).power(18),
            serviceFeeAmount: BigUInt(150) * BigUInt(10).power(18),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "EUR",
                    "p": "0.94",
                    "m": "SEPA"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID,
            state: .awaitingPaymentSent,
            role: .makerAndBuyer
        ),
        sampleSwapIds[1]: try! Swap(
            isCreated: true,
            requiresFill: false,
            id: sampleSwapIds[1],
            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            makerInterfaceID: Data(),
            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
            takerInterfaceID: Data(),
            stablecoin: EthereumAddress("0x2E983A1Ba5e8b38AAAeC4B440B9dDcFBf72E15d1")!, // USDC on Hardhat
            amountLowerBound: 10_000 * BigUInt(10).power(6),
            amountUpperBound: 20_000 * BigUInt(10).power(6),
            securityDepositAmount: 2_000 * BigUInt(10).power(6),
            takenSwapAmount: 15_000 * BigUInt(10).power(6),
            serviceFeeAmount: BigUInt(150) * BigUInt(10).power(6),
            serviceFeeRate: BigUInt(100),
            direction: .buy,
            onChainSettlementMethod:
                """
                {
                    "f": "USD",
                    "p": "1.00",
                    "m": "SWIFT"
                }
                """.data(using: .utf8)!,
            protocolVersion: BigUInt.zero,
            isPaymentSent: false,
            isPaymentReceived: false,
            hasBuyerClosed: false,
            hasSellerClosed: false,
            onChainDisputeRaiser: BigUInt.zero,
            chainID: BigUInt(31337), // Hardhat blockchain ID
            state: .takeOfferTransactionSent,
            role: .takerAndSeller
        ),
    ]
}

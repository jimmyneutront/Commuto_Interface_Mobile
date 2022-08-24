//
//  SwapService.swift
//  iosApp
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import BigInt

/**
 The main Swap Service. It is responsible for processing and organizing swap-related data that it receives from `BlockchainService`, `P2PService` and `OfferService` in order to maintain an accurate list of all swaps in a `SwapTruthSource`.
 */
class SwapService: SwapNotifiable {
    
    /**
     Initializes a new SwapService object.
     
     - Parameters:
        - databaseService: The `DatabaseService` that this `SwapService` uses for persistent storage.
        - keyManagerService: The `KeyManagerService` that this `SwapService` will use for managing keys.
     */
    init(
        databaseService: DatabaseService,
        keyManagerService: KeyManagerService
    ) {
        self.databaseService = databaseService
        self.keyManagerService = keyManagerService
    }
    
    /**
     SwapService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "SwapService")
    
    /**
     An object adopting `SwapTruthSource` that acts as a single  source of truth for all swap-related data.
     */
    var swapTruthSource: SwapTruthSource? = nil
    
    /**
     The `BlockchainService` that this uses to interact with the blockchain.
     */
    var blockchainService: BlockchainService? = nil
    
    /**
     The `P2PService` that this uses for interacting with the peer-to-peer network.
     */
    var p2pService: P2PService? = nil
    
    /**
     The `DatabaseService` that this uses for persistent storage.
     */
    private let databaseService: DatabaseService
    
    /**
     The `KeyManagerService` that this uses for managing keys.
     */
    private let keyManagerService: KeyManagerService
    
    /**
     Sends a [Taker Information Message](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt) for an offer taken by the user of this interface, with an ID equal to `swapID` and a blockchain ID equal to `chainID`.
     
     This updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingTakerInformation`, creates and sends a Taker Information Message, and then updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingMakerInformation`.
     
     - Parameters:
        - swapID: The ID of the swap for which taker information will be sent.
        - chainID: The ID of the blockchain on which the swap exists.
     
     - Throws `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, if the swap is not found in persistent storage, if this is unable to create maker and taker interface IDs from the values in persistent storage, if the maker's public key is not found, if the taker's key pair is not found, or if `p2pService` is `nil`.
     */
    func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws {
        logger.notice("sendTakerInformationMessage: preparing to send for \(swapID.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during sendTakerInformationMessage call for \(swapID.uuidString)")
        }
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingTakerInformation.asString)
        DispatchQueue.main.async {
            swapTruthSource.swaps[swapID]?.state = .awaitingTakerInformation
        }
        // Since we are the taker of this swap, we should have it in persistent storage
        guard let swapInDatabase = try databaseService.getSwap(id: swapID.asData().base64EncodedString()) else {
            throw SwapServiceError.unexpectedNilError(desc: "Could not find swap \(swapID.uuidString) in persistent storage")
        }
        guard let makerInterfaceID = Data(base64Encoded: swapInDatabase.makerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Unable to get maker interface ID for \(swapID.uuidString). makerInterfaceID string: \(swapInDatabase.makerInterfaceID)")
        }
        // The user of this interface has taken the swap. Since taking a swap is not allowed unless we have a copy of the maker's public key, we should have said public key in storage.
        guard let makerPublicKey = try keyManagerService.getPublicKey(interfaceId: makerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Could not find maker's public key for \(swapID.uuidString)")
        }
        guard let takerInterfaceID = Data(base64Encoded: swapInDatabase.takerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Unable to get taker interface ID for \(swapID.uuidString). takerInterfaceID string: \(swapInDatabase.takerInterfaceID)")
        }
        // Since the user of this interface has taken the swap, we should have a key pair for the swap in persistent storage.
        guard let takerKeyPair = try keyManagerService.getKeyPair(interfaceId: takerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Could not find taker's (user's) key pair for \(swapID.uuidString)")
        }
        #warning("TODO: get actual payment details once settlementMethodService is implemented")
        let paymentDetailsString = "TEMPORARY"
        guard let p2pService = p2pService else {
            throw SwapServiceError.unexpectedNilError(desc: "p2pService was nil during sendTakerInformationMessage call for \(swapID.uuidString)")
        }
        logger.notice("sendTakerInformationMessage: sending for \(swapID.uuidString)")
        try p2pService.sendTakerInformation(makerPublicKey: makerPublicKey, takerKeyPair: takerKeyPair, swapID: swapID, paymentDetails: paymentDetailsString)
        logger.notice("sendTakerInformationMessage: sent for \(swapID.uuidString)")
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingMakerInformation.asString)
        DispatchQueue.main.async {
            swapTruthSource.swaps[swapID]?.state = .awaitingMakerInformation
        }
    }
    
    /**
     Gets the on-chain [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) with the specified swap ID, creates and persistently stores a new `Swap` with state `SwapState.awaitingTakerInformation` using the on chain swap, and maps `swapID` lto the new `Swap` on the main `DispatchQueue`.
     
     - Parameters:
        - swapID: The ID of the swap for which to update state.
        - chainID The ID of the blockchain on which the swap exists.
     
     - Throws `SwapServiceError.unexpectedNilError` of `swapTruthSource` is `nil`.
     */
    func handleNewSwap(swapID: UUID, chainID: BigUInt) throws {
        logger.notice("handleNewSwap: getting on-chain struct for \(swapID)")
        guard let blockchainService = blockchainService else {
            throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during handleNewSwap call for \(swapID.uuidString)")
        }
        guard let swapOnChain = try blockchainService.getSwap(id: swapID) else {
            logger.error("handleNewSwap: could not find \(swapID.uuidString) on chain, throwing error")
            throw SwapServiceError.unexpectedNilError(desc: "Could not find \(swapID.uuidString) on chain")
        }
        let direction: OfferDirection = try {
            switch(swapOnChain.direction) {
            case BigUInt(0):
                return OfferDirection.buy
            case BigUInt(1):
                return OfferDirection.sell
            default:
                throw SwapServiceError.invalidValueError(desc: "Swap \(swapID.uuidString) has invalid direction: \(String(swapOnChain.direction))")
            }
        }()
        let newSwap = try Swap(
            isCreated: swapOnChain.isCreated,
            requiresFill: swapOnChain.requiresFill,
            id: swapID,
            maker: swapOnChain.maker,
            makerInterfaceID: swapOnChain.makerInterfaceID,
            taker: swapOnChain.taker,
            takerInterfaceID: swapOnChain.takerInterfaceID,
            stablecoin: swapOnChain.stablecoin,
            amountLowerBound: swapOnChain.amountLowerBound,
            amountUpperBound: swapOnChain.amountUpperBound,
            securityDepositAmount: swapOnChain.securityDepositAmount,
            takenSwapAmount: swapOnChain.takenSwapAmount,
            serviceFeeAmount: swapOnChain.serviceFeeAmount,
            serviceFeeRate: swapOnChain.serviceFeeRate,
            direction: direction,
            onChainSettlementMethod: swapOnChain.settlementMethod,
            protocolVersion: swapOnChain.protocolVersion,
            isPaymentSent: swapOnChain.isPaymentSent,
            isPaymentReceived: swapOnChain.isPaymentReceived,
            hasBuyerClosed: swapOnChain.hasBuyerClosed,
            hasSellerClosed: swapOnChain.hasSellerClosed,
            onChainDisputeRaiser: swapOnChain.disputeRaiser,
            chainID: chainID,
            state: .awaitingTakerInformation
        )
        #warning("TODO: check for taker information once SettlementMethodService is implemented")
        // Persistently store new swap object
        logger.notice("handleNewSwap: persistently storing \(swapID.uuidString)")
        let newSwapForDatabase = DatabaseSwap(
            id: newSwap.id.asData().base64EncodedString(),
            isCreated: newSwap.isCreated,
            requiresFill: newSwap.requiresFill,
            maker: newSwap.maker.addressData.toHexString(),
            makerInterfaceID: newSwap.makerInterfaceID.base64EncodedString(),
            taker: newSwap.taker.addressData.toHexString(),
            takerInterfaceID: newSwap.takerInterfaceID.base64EncodedString(),
            stablecoin: newSwap.stablecoin.addressData.toHexString(),
            amountLowerBound: String(newSwap.amountLowerBound),
            amountUpperBound: String(newSwap.amountUpperBound),
            securityDepositAmount: String(newSwap.securityDepositAmount),
            takenSwapAmount: String(newSwap.takenSwapAmount),
            serviceFeeAmount: String(newSwap.serviceFeeAmount),
            serviceFeeRate: String(newSwap.serviceFeeRate),
            onChainDirection: String(newSwap.onChainDirection),
            onChainSettlementMethod: newSwap.onChainSettlementMethod.base64EncodedString(),
            protocolVersion: String(newSwap.protocolVersion),
            isPaymentSent: newSwap.isPaymentSent,
            isPaymentReceived: newSwap.isPaymentReceived,
            hasBuyerClosed: newSwap.hasBuyerClosed,
            hasSellerClosed: newSwap.hasSellerClosed,
            onChainDisputeRaiser: String(newSwap.onChainDisputeRaiser),
            chainID: String(newSwap.chainID),
            state: newSwap.state.asString
        )
        try databaseService.storeSwap(swap: newSwapForDatabase)
        // Add new Swap to swapTruthSource
        guard var swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleNewSwap call for \(swapID.uuidString)")
        }
        DispatchQueue.main.async {
            swapTruthSource.swaps[swapID] = newSwap
        }
        logger.notice("handleNewSwap: successfully handled \(swapID.uuidString)")
    }
    
}
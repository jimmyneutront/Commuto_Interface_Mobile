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
 The main Swap Service. It is responsible for processing and organizing swap-related data that it receives from `BlockchainService`, `P2PService` and `OfferService` in order to maintain an accurate list of all swaps in a `SwapTruthSource`
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
     Announces taker information for an offer taken by the user of this interface, with an ID equal to `swapID` and a blockchain ID equal to `chainID`.
     
     This updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingTakerInformation`, creates and sends a Taker Information Announcement message, and then updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingMakerInformation.`
     
     - Parameters:
        - swapID: The ID of the swap for which taker information will be announced.
        - chainID: The ID of the blockchain on which the swap exists.
     
     - Throws `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, if the swap is not found in persistent storage, if this is unable to create maker and taker interface IDs from the values in persistent storage, if the maker's public key is not found, if the taker's key pair is not found, or if `p2pService` is `nil`.
     */
    func announceTakerInformation(swapID: UUID, chainID: BigUInt) throws {
        logger.notice("announceTakerInformation: preparing to announce for \(swapID.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during announceTakerInformation call for \(swapID.uuidString)")
        }
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingTakerInformation.asString)
        DispatchQueue.main.async {
            swapTruthSource.swaps[swapID]?.state = .awaitingTakerInformation
        }
        // Since we are the taker of this swap, we should have it in persistent storage.
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
            throw SwapServiceError.unexpectedNilError(desc: "p2pService was nil during announceTakerInformation call for \(swapID.uuidString)")
        }
        logger.notice("announceTakerInformation: announcing for \(swapID.uuidString)")
        try p2pService.announceTakerInformation(makerPublicKey: makerPublicKey, takerKeyPair: takerKeyPair, swapID: swapID, paymentDetails: paymentDetailsString)
        logger.notice("announceTakerInformation: announced for \(swapID.uuidString)")
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingMakerInformation.asString)
        DispatchQueue.main.async {
            swapTruthSource.swaps[swapID]?.state = .awaitingMakerInformation
        }
    }
    
}

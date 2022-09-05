//
//  SwapService.swift
//  iosApp
//
//  Created by jimmyt on 8/21/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import os
import PromiseKit
import BigInt

/**
 The main Swap Service. It is responsible for processing and organizing swap-related data that it receives from `BlockchainService`, `P2PService` and `OfferService` in order to maintain an accurate list of all swaps in a `SwapTruthSource`.
 */
class SwapService: SwapNotifiable, SwapMessageNotifiable {

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
     Attempts to fill a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap), using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that the user is the maker and stablecoin seller of `swapToFill`, and that `swapToFill` can actually be filled. Then this approves token transfer for `swapToFill.takenSwapAmount` to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, calls the CommutoSwap contract's [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) function (via `blockchainService`), persistently updates the state of the swap to `fillSwapTransactionBroadcast`, and sets `swapToFill.requiresFill` to false. Finally, on the main `DispatchQueue`, this updates the state of `swapToFill` to `fillSwapTransactionBroadcast`.
     
     - Parameters:
        - swapToFill: The `Swap` that this function will fill.
        - afterPossibilityCheck: A closure that will be executed after this has ensured that the swap can be filled.
        - afterTransferApproval: A closure that will be executed after the token transfer approval to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
     
     - Returns: An empty promise that will be fulfilled with the Swap is filled.
     
     - Throws: An `SwapServiceError.transactionWillRevertError` if `swapToFill` is not a maker-as-seller swap and the user is not the maker, or if `swapToFill`'s state is not `awaitingFilling`, or a `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`.
     */
    func fillSwap(
        swapToFill: Swap,
        afterPossibilityCheck: (() -> Void)? = nil,
        afterTransferApproval: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Swap> { seal in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.logger.notice("fillSwap: checking that \(swapToFill.id.uuidString) can be filled")
                    do {
                        // Ensure that the user is the maker and seller for the swap
                        guard swapToFill.role == .makerAndSeller else {
                            throw SwapServiceError.transactionWillRevertError(desc: "Only Maker-As-Seller swaps can be filled")
                        }
                        // Ensure that this swap is awaiting filling
                        guard swapToFill.state == .awaitingFilling else {
                            throw SwapServiceError.transactionWillRevertError(desc: "This Swap cannot currently be filled")
                        }
                        if let afterPossibilityCheck = afterPossibilityCheck {
                            afterPossibilityCheck()
                        }
                        seal.fulfill(swapToFill)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] swapToFill -> Promise<(Void, Swap)> in
                logger.notice("fillSwap: authorizing transfer for \(swapToFill.id.uuidString). Amount: \(String(swapToFill.takenSwapAmount))")
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during fillSwap call for \(swapToFill.id.uuidString)")
                }
                return blockchainService.approveTokenTransfer(tokenAddress: swapToFill.stablecoin, destinationAddress: blockchainService.commutoSwapAddress, amount: swapToFill.takenSwapAmount).map { ($0, swapToFill) }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, swapToFill -> Promise<(Void, Swap)> in
                if let afterTransferApproval = afterTransferApproval {
                    afterTransferApproval()
                }
                logger.notice("fillSwap: filling \(swapToFill.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during fillSwap call for \(swapToFill.id.uuidString)")
                }
                return blockchainService.fillSwap(id: swapToFill.id).map { ($0, swapToFill) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, filledSwap in
                logger.notice("fillSwap: filled \(filledSwap.id.uuidString)")
                let swapIDString = filledSwap.id.asData().base64EncodedString()
                try databaseService.updateSwapState(swapID: swapIDString, chainID: String(filledSwap.chainID), state: SwapState.fillSwapTransactionBroadcast.asString)
                try databaseService.updateSwapRequiresFill(swapID: swapIDString, chainID: String(filledSwap.chainID), requiresFill: false)
                // This is not a @Published property, so we can update it from a background thread
                filledSwap.requiresFill = false
            }.done(on: DispatchQueue.main) { _, filledSwap in
                filledSwap.state = .fillSwapTransactionBroadcast
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("fillSwap: encountered error during call for \(swapToFill.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Gets the on-chain [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) with the specified swap ID, creates and persistently stores a new `Swap` with state `SwapState.awaitingTakerInformation` using the on chain swap, and maps `swapID` lto the new `Swap` on the main `DispatchQueue`. This should only be called for swaps made by the user of this interface.
     
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
        var swapRole: SwapRole {
            switch direction {
            case .buy:
                return SwapRole.makerAndBuyer
            case .sell:
                return SwapRole.makerAndSeller
            }
        }
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
            state: .awaitingTakerInformation,
            role: swapRole
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
            state: newSwap.state.asString,
            role: newSwap.role.asString
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
    
    /**
     The function called by `P2PService` to notify `SwapService` of a `TakerInformationMessage`.
     
     Once notified, this checks that there exists in `swapTruthSource` a `Swap` with the ID specified in `message`. If there is, this checks that the interface ID of the public key contained in `message` is equal to the interface ID of the swap taker. If it is, this persistently stores the public key in `message`, securely persistently stores the payment information in `message`, updates the state of the swap to `SwapState.awaitingMakerInformation` (both persistently and in `swapTruthSource` on the main `DispatchQueue`), and creates and sends a Maker Information Message. Then, if the swap is a maker-as-seller swap, this updates the state of the swap to `SwapState.awaitingFilling`. Otherwise, the swap is a maker-as-buyer swap, and this updates the state of the swap to `SwapState.awaitingPaymentSent`. The state is updated both persistently and in `swapTruthSource`.
     
     - Parameter message: The `TakerInformationMessage` to handle.
     
     - Throws `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil` or if `p2pService` is `nil`, or if `keyManagerService` does not have the key pair with the interface ID specified in `message`.
     */
    func handleTakerInformationMessage(_ message: TakerInformationMessage) throws {
        logger.notice("handleTakerInformationMessage: handling for \(message.swapID.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleTakerInformationMessage call for \(message.swapID.uuidString)")
        }
        let swap = swapTruthSource.swaps[message.swapID]
        if let swap = swap {
            if message.publicKey.interfaceId == swap.takerInterfaceID {
                logger.notice("handleTakerInformationMessage: persistently storing public key \(message.publicKey.interfaceId.base64EncodedString()) for \(message.swapID.uuidString)")
                try keyManagerService.storePublicKey(pubKey: message.publicKey)
                #warning("TODO: securely store taker settlement method information once SettlementMethodService is implemented")
                logger.notice("handleTakerInformationMessage: updating \(message.swapID.uuidString) to \(SwapState.awaitingMakerInformation.asString)")
                try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingMakerInformation.asString)
                DispatchQueue.main.async {
                    swap.state = SwapState.awaitingMakerInformation
                }
                #warning("TODO: get actual settlement method details once SettlementMethodService is implemented")
                guard let makerKeyPair = try keyManagerService.getKeyPair(interfaceId: swap.makerInterfaceID) else {
                    throw SwapServiceError.unexpectedNilError(desc: "Could not find key pair for \(message.swapID.uuidString) while handling Taker Information Message")
                }
                let settlementMethodDetailsString = "TEMPORARY"
                guard let p2pService = p2pService else {
                    throw SwapServiceError.unexpectedNilError(desc: "p2pService was nil during handleTakerInformationMessage call for \(message.swapID.uuidString)")
                }
                logger.notice("handleTakerInformationMessage: sending for \(message.swapID.uuidString)")
                try p2pService.sendMakerInformation(takerPublicKey: message.publicKey, makerKeyPair: makerKeyPair, swapID: swap.id, settlementMethodDetails: settlementMethodDetailsString)
                logger.notice("handleTakerInformationMessage: sent for \(message.swapID.uuidString)")
                switch swap.direction {
                case .buy:
                    logger.notice("handleTakerInformationMessage: updating state of BUY swap \(message.swapID.uuidString) to \(SwapState.awaitingPaymentSent.asString)")
                    try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingPaymentSent.asString)
                    DispatchQueue.main.async {
                        swap.state = SwapState.awaitingMakerInformation
                    }
                case .sell:
                    logger.notice("handleTakerInformationMessage: updating state of SELL swap \(message.swapID.uuidString) to \(SwapState.awaitingFilling.asString)")
                    try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingFilling.asString)
                    DispatchQueue.main.async {
                        swap.state = SwapState.awaitingFilling
                    }
                }
            } else {
                logger.warning("handleTakerInformationMessage: got message for \(message.swapID.uuidString) that was not sent by swap taker")
            }
        } else {
            logger.warning("handleTakerInformationMessage: got message for \(message.swapID.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by `P2PService` to notify `SwapService` of a `MakerInformationMessage`.
     
     Once notified, this checks that there exists in `swapTruthSource` a `Swap` with the ID specified in `message`. If there is, this checks that the interface ID of the message sender is equal to the interface ID of the swap maker and that the interface ID of the message's intended recipient is equal to the interface ID of the swap taker. If they are, this securely persistently stores the settlement method information in `message`. Then, if this swap is a maker-as-buyer swap, this updates the state of the swap to `SwapState.awaitingPaymentSent`. Otherwise, the swap is a maker-as-seller swap, and this updates the state of the swap to `SwapState.awaitingFilling`. The state is updated both persistently and in `swapTruthSource`.
     
     - Parameters:
        - message: The `MakerInformationMessage` to handle.
        - senderInterfaceID: The interface ID of the message's sender.
        - recipientInterfaceID: The interface ID of the message's intended recipient.
     
     - Throws `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`.
     */
    func handleMakerInformationMessage(_ message: MakerInformationMessage, senderInterfaceID: Data, recipientInterfaceID: Data) throws {
        logger.notice("handleMakerInformationMessage: handling for \(message.swapID.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleMakerInformationMessage call for \(message.swapID.uuidString)")
        }
        let swap = swapTruthSource.swaps[message.swapID]
        if let swap = swap {
            if senderInterfaceID != swap.makerInterfaceID {
                logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) that was not sent by swap maker")
                return
            }
            if recipientInterfaceID != swap.takerInterfaceID {
                logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) with recipient interface ID \(recipientInterfaceID.base64EncodedString()) that doesn't match taker interface ID \(swap.takerInterfaceID.base64EncodedString())")
                return
            }
            #warning("TODO: securely store maker settlement method information once SettlementMethodService is implemented")
            switch swap.direction {
            case .buy:
                logger.notice("handleMakerInformationMessage: updating state of BUY swap \(message.swapID.uuidString) to \(SwapState.awaitingPaymentSent.asString)")
                try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingPaymentSent.asString)
                DispatchQueue.main.async {
                    swap.state = SwapState.awaitingPaymentSent
                }
            case .sell:
                logger.notice("handleMakerInformationMessage: updating state of SELL swap \(message.swapID.uuidString) to \(SwapState.awaitingFilling.asString)")
                try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingFilling.asString)
                DispatchQueue.main.async {
                    swap.state = SwapState.awaitingFilling
                }
            }
        } else {
            logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) which was not found in swapTruthSource")
        }
    }
    
}

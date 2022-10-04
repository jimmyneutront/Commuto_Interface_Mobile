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
     Initializes a new `SwapService` object.
     
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
     An object adopting `SwapTruthSource` that acts as a single source of truth for all swap-related data.
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
    If `swapID` and `chainID` correspond to an offer taken by the user of this interface, this sends a [Taker Information Message](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt): this updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingTakerInformation`, creates and sends a Taker Information Message, and then updates the state of the swap with the specified ID (both persistently and in `swapTruthSource`) to `SwapState.awaitingMakerInformation`, and then returns `true` to indicate that the swap was taken by the user of this interface and thus the message has been sent. If `swapID` and `chainID` do not correspond to an offer taken by the user of this interface, this returns `false`.
     
     - Parameters:
        - swapID: The ID of the swap for which taker information should be sent.
        - chainID: The ID of the blockchain on which the swap exists.
     
     - Throws `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, if the maker's public key is not found, if the taker's key pair is not found, or if `p2pService` is `nil`, or a `SwapServiceError.nonmatchingChainIDError` if `chainID` does not match that of the swap corresponding to `swapID` in `swapTruthSource`.
     
     if the swap is not found in persistent storage, if this is unable to create maker and taker interface IDs from the values in persistent storage, if the maker's public key is not found, if the taker's key pair is not found, or if `p2pService` is `nil`.
     */
    func sendTakerInformationMessage(swapID: UUID, chainID: BigUInt) throws -> Bool {
        logger.notice("sendTakerInformationMessage: checking if message should be sent for \(swapID.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during sendTakerInformationMessage call for \(swapID.uuidString)")
        }
        guard let swap = swapTruthSource.swaps[swapID] else {
            logger.notice("sendTakerInformationMessage: could not find \(swapID.uuidString) in swapTruthSource")
            return false
        }
        guard swap.chainID == chainID else {
            throw SwapServiceError.nonmatchingChainIDError(desc: "Passed chain ID \(String(chainID)) does not match that of swap \(swapID.uuidString): \(String(swap.chainID))")
        }
        guard swap.role == .takerAndBuyer || swap.role == .takerAndSeller else {
            logger.notice("sendTakerInformationMessage: user is not taker in \(swapID.uuidString)")
            return false
        }
        logger.notice("sendTakerInformationMessage: user is taker in \(swapID.uuidString), sending message")
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingTakerInformation.asString)
        DispatchQueue.main.async {
            swap.state = .awaitingTakerInformation
        }
        // The user of this interface has taken the swap. Since taking a swap is not allowed unless we have a copy of the maker's public key, we should have said public key in storage.
        guard let makerPublicKey = try keyManagerService.getPublicKey(interfaceId: swap.makerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Could not find maker's public key for \(swapID.uuidString)")
        }
        // Since the user of this interface has taken the swap, we should have a key pair for the swap in persistent storage.
        guard let takerKeyPair = try keyManagerService.getKeyPair(interfaceId: swap.takerInterfaceID) else {
            throw SwapServiceError.unexpectedNilError(desc: "Could not find taker's (user's) key pair for \(swapID.uuidString)")
        }
        guard let p2pService = p2pService else {
            throw SwapServiceError.unexpectedNilError(desc: "p2pService was nil during sendTakerInformationMessage call for \(swapID.uuidString)")
        }
        logger.notice("sendTakerInformationMessage: sending for \(swapID.uuidString)")
        if swap.takerPrivateSettlementMethodData == nil {
            logger.warning("sendTakerInformationMessage: taker info is nil for \(swapID.uuidString)")
        }
        try p2pService.sendTakerInformation(makerPublicKey: makerPublicKey, takerKeyPair: takerKeyPair, swapID: swapID, paymentDetails: swap.takerPrivateSettlementMethodData)
        logger.notice("sendTakerInformationMessage: sent for \(swapID.uuidString)")
        try databaseService.updateSwapState(swapID: swapID.asData().base64EncodedString(), chainID: String(chainID), state: SwapState.awaitingMakerInformation.asString)
        DispatchQueue.main.async {
            swap.state = .awaitingMakerInformation
        }
        // We have sent a taker info message for this swap, so we return true
        return true
    }
    
    /**
     Attempts to fill a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap), using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that the user is the maker and stablecoin seller of `swapToFill`, and that `swapToFill` can actually be filled. Then this approves token transfer for `swapToFill.takenSwapAmount` to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, calls the CommutoSwap contract's [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) function (via `blockchainService`), persistently updates the state of the swap to `fillSwapTransactionBroadcast`, and sets `swapToFill.requiresFill` to false. Finally, on the main `DispatchQueue`, this updates the state of `swapToFill` to `fillSwapTransactionBroadcast`.
     
     - Parameters:
        - swapToFill: The `Swap` that this function will fill.
        - afterPossibilityCheck: A closure that will be executed after this has ensured that the swap can be filled.
        - afterTransferApproval: A closure that will be executed after the token transfer approval to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
     
     - Returns: An empty promise that will be fulfilled with the Swap is filled.
     
     - Throws: A `SwapServiceError.transactionWillRevertError` if `swapToFill` is not a maker-as-seller swap and the user is not the maker, or if `swapToFill`'s state is not `awaitingFilling`, or a `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`.
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
     Reports that payment has been sent to the seller in a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that the user is the buyer in `swap` and that reporting payment sending is currently possible for `swap`. Then this calls the CommutoSwap contract's [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) function (via `blockchainService`), and persistently updates the state of the swap to `reportPaymentSentTransactionBroadcast`. Finally, on the main `DispatchQueue`, this updates the state of `swap` to `reportPaymentSentTransactionBroadcast`.
     
     - Parameters:
        - swap: The `Swap` for which this function will report the sending of payment.
        - afterPossibilityCheck: A closure that will be executed after this has ensured that payment sending can be reported for the swap.
     
     - Returns: An empty promise that will be fulfilled when payment sending has been reported.
     
     - Throws: A `SwapServiceError.transactionWillRevertError` if the user is not the buyer for `swap`, or if `swap`'s state is not `awaitingPaymentSent`, or a `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`.
     */
    func reportPaymentSent(
        swap: Swap,
        afterPossibilityCheck: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Swap> { seal in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.logger.notice("reportPaymentSent: checking reporting is possible for \(swap.id.uuidString)")
                    do {
                        // Ensure that the user is the buyer for the swap
                        guard swap.role == .makerAndBuyer || swap.role == .takerAndBuyer else {
                            throw SwapServiceError.transactionWillRevertError(desc: "Only the Buyer can report sending payment")
                        }
                        // Ensure that this swap is awaiting reporting of payment sent
                        guard swap.state == .awaitingPaymentSent else {
                            throw SwapServiceError.transactionWillRevertError(desc: "Payment sending cannot currently be reported for this swap")
                        }
                        if let afterPossibilityCheck = afterPossibilityCheck {
                            afterPossibilityCheck()
                        }
                        seal.fulfill(swap)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] swap -> Promise<(Void, Swap)> in
                logger.notice("reportPaymentSent: reporting \(swap.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during reportPaymentSent call for \(swap.id.uuidString)")
                }
                return blockchainService.reportPaymentSent(id: swap.id).map { ($0, swap) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, swap in
                logger.notice("reportPaymentSent: reported for \(swap.id)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.reportPaymentSentTransactionBroadcast.asString)
            }.done(on: DispatchQueue.main) { _, swap in
                swap.state = .reportPaymentSentTransactionBroadcast
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("reportPaymentSent: encountered error during call for \(swap.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    
    /**
     Reports that payment has been received by the seller in a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that the user is the seller in `swap` and that reporting the receipt of payment is currently possible for `swap`. Then this calls the CommutoSwap contract's [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) function (via `blockchainService`), and persistently updates the state of the swap to `reportPaymentReceivedTransactionBroadcast`. Finally, on the main `DispatchQueue`, this updates the state of `swap` to `reportPaymentReceivedTransactionBroadcast`.
     
     - Parameters:
        - swap: The `Swap` for which this function will report the receipt of payment.
        - afterPossibilityCheck: A closure that will be executed after this has ensured that payment receipt can be reported for the swap.
     
     - Returns: An empty promise that will be fulfilled when payment receipt has been reported.
     
     - Throws: A `SwapServiceError.transactionWillRevertError` if the user is not the seller for `swap`, or if `swap`'s state is not `awaitingPaymentReceived`, or a `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`.
     */
    func reportPaymentReceived(
        swap: Swap,
        afterPossibilityCheck: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Swap> { seal in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.logger.notice("reportPaymentReceived: checking reporting is possible for \(swap.id.uuidString)")
                    do {
                        // Ensure that the user is the seller for the swap
                        guard swap.role == .makerAndSeller || swap.role == .takerAndSeller else {
                            throw SwapServiceError.transactionWillRevertError(desc: "Only the Seller can report receiving payment")
                        }
                        // Ensure that this swap is awaiting reporting of payment received
                        guard swap.state == .awaitingPaymentReceived else {
                            throw SwapServiceError.transactionWillRevertError(desc: "Receiving payment cannot currently be reported for this swap")
                        }
                        if let afterPossibilityCheck = afterPossibilityCheck {
                            afterPossibilityCheck()
                        }
                        seal.fulfill(swap)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] swap -> Promise<(Void, Swap)> in
                logger.notice("reportPaymentReceived: reporting \(swap.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during reportPaymentReceived call for \(swap.id.uuidString)")
                }
                return blockchainService.reportPaymentReceived(id: swap.id).map { ($0, swap) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, swap in
                logger.notice("reportPaymentReceived: reported for \(swap.id)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.reportPaymentReceivedTransactionBroadcast.asString)
            }.done(on: DispatchQueue.main) { _, swap in
                swap.state = .reportPaymentReceivedTransactionBroadcast
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("reportPaymentReceived: encountered error during call for \(swap.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to close a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that `swap` can be closed.. Then this calls the CommutoSwap contract's [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) function (via `blockchainService`), and persistently updates the state of the swap to `closeSwapTransactionBroadcast`. Finally, this does the same to `swap`, updating `state` on the main `DispatchQueue`.
     
     - Parameters:
        - swap: The `Swap` this function will close.
        - afterPossibilityCheck: A closure that will be executed after this has ensured `swap` can be closed.
     
     - Returns: An empty promise that will be fulfilled when `swap` has been closed.
     
     - Throws: A `SwapServiceError.transactionWillRevertError` if `swap`'s state is not `awaitingClosing`, or a `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`.
     */
    func closeSwap(
        swap: Swap,
        afterPossibilityCheck: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Swap> { seal in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.logger.notice("closeSwap: checking if \(swap.id.uuidString) can be closed")
                    do {
                        // Ensure that this swap is awaiting closing
                        guard swap.state == .awaitingClosing else {
                            throw SwapServiceError.transactionWillRevertError(desc: "This swap cannot currently be closed")
                        }
                        if let afterPossibilityCheck = afterPossibilityCheck {
                            afterPossibilityCheck()
                        }
                        seal.fulfill(swap)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] swap -> Promise<(Void, Swap)> in
                logger.notice("closeSwap: closing \(swap.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during closeSwap call for \(swap.id.uuidString)")
                }
                return blockchainService.closeSwap(id: swap.id).map { ($0, swap) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, swap in
                logger.notice("closeSwap: closed \(swap.id)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.closeSwapTransactionBroadcast.asString)
            }.done(on: DispatchQueue.main) { _, swap in
                swap.state = .closeSwapTransactionBroadcast
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("closeSwap: encountered error during call for \(swap.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Gets the on-chain [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) corresponding to `takenOffer`, determines which one of `takenOffer`'s settlement methods the offer taker has selected, gets the user's (maker's) private settlement method data for this settlement method, and creates and persistently stores a new `Swap` with state `SwapState.awaitingTakerInformation` using the on-chain swap and the user's (maker's) private settlement method data, and maps `takenOffer`'s ID to the new `Swap` on the main `DispatchQueue`. This should only be called for swaps made by the user of this interface.
     
     - Parameter takenOffer: The `Offer` made by the user of this interface that has been taken and now corresponds to a swap.
     
     - Throws `SwapServiceError.unexpectedNilError` if `blockchainService` or `swapTruthSource` are `nil` or if this is unable to find the corresponding swap on chain, and `SwapServiceError.invalidValueError` if the on-chain swap has an invalid direction.
     */
    func handleNewSwap(takenOffer: Offer) throws {
        logger.notice("handleNewSwap: getting on-chain struct for \(takenOffer.id.uuidString)")
        guard let blockchainService = blockchainService else {
            throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during handleNewSwap call for \(takenOffer.id.uuidString)")
        }
        guard let swapOnChain = try blockchainService.getSwap(id: takenOffer.id) else {
            logger.error("handleNewSwap: could not find \(takenOffer.id.uuidString) on chain, throwing error")
            throw SwapServiceError.unexpectedNilError(desc: "Could not find \(takenOffer.id.uuidString) on chain")
        }
        let direction: OfferDirection = try {
            switch(swapOnChain.direction) {
            case BigUInt(0):
                return OfferDirection.buy
            case BigUInt(1):
                return OfferDirection.sell
            default:
                throw SwapServiceError.invalidValueError(desc: "Swap \(takenOffer.id.uuidString) has invalid direction: \(String(swapOnChain.direction))")
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
        let deserializedSelectedSettlementMethod = try? JSONDecoder().decode(SettlementMethod.self, from: swapOnChain.settlementMethod)
        if deserializedSelectedSettlementMethod == nil {
            logger.warning("handleNewSwap: unable to deserialize selected settlement method \(swapOnChain.settlementMethod.base64EncodedString()) for \(takenOffer.id)")
        }
        let selectedSettlementMethod = takenOffer.settlementMethods.first { settlementMethod in
            if deserializedSelectedSettlementMethod?.currency == settlementMethod.currency && deserializedSelectedSettlementMethod?.price == settlementMethod.price && deserializedSelectedSettlementMethod?.method == settlementMethod.method {
                return true
            } else {
                return false
            }
        }
        if selectedSettlementMethod == nil {
            logger.warning("handleNewSwap: unable to find settlement for offer \(takenOffer.id) matching that selected by taker: \(swapOnChain.settlementMethod.base64EncodedString())")
        }
        let newSwap = try Swap(
            isCreated: swapOnChain.isCreated,
            requiresFill: swapOnChain.requiresFill,
            id: takenOffer.id,
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
            chainID: takenOffer.chainID,
            state: .awaitingTakerInformation,
            role: swapRole
        )
        newSwap.makerPrivateSettlementMethodData = selectedSettlementMethod?.privateData
        // Persistently store new swap object
        logger.notice("handleNewSwap: persistently storing \(takenOffer.id.uuidString)")
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
            makerPrivateSettlementMethodData: newSwap.makerPrivateSettlementMethodData,
            takerPrivateSettlementMethodData: nil,
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
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleNewSwap call for \(takenOffer.id.uuidString)")
        }
        DispatchQueue.main.async {
            swapTruthSource.swaps[takenOffer.id] = newSwap
        }
        logger.notice("handleNewSwap: successfully handled \(takenOffer.id.uuidString)")
    }
    
    /**
     The function called by `P2PService` to notify `SwapService` of a `TakerInformationMessage`.
     
     Once notified, this checks that there exists in `swapTruthSource` a `Swap` with the ID specified in `message`. If there is, this checks that the interface ID of the public key contained in `message` is equal to the interface ID of the swap taker, and that the user is the maker of the swap. If these conditions are met,  this persistently stores the public key in `message`, securely persistently stores the taker's private settlement method data contained in `message`, updates the state of the swap to `SwapState.awaitingMakerInformation` (both persistently and in `swapTruthSource` on the main `DispatchQueue`), and creates and sends a Maker Information Message. Then, if the swap is a maker-as-seller swap, this updates the state of the swap to `SwapState.awaitingFilling`. Otherwise, the swap is a maker-as-buyer swap, and this updates the state of the swap to `SwapState.awaitingPaymentSent`. The state is updated both persistently and in `swapTruthSource`.
     
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
                // We should only handle this message if we are the maker of the swap; otherwise, we are the taker and we would be handling our own message
                if swap.role == SwapRole.makerAndBuyer || swap.role == SwapRole.makerAndSeller {
                    logger.notice("handleTakerInformationMessage: persistently storing public key \(message.publicKey.interfaceId.base64EncodedString()) for \(message.swapID.uuidString)")
                    try keyManagerService.storePublicKey(pubKey: message.publicKey)
                    let swapIDB64String = message.swapID.asData().base64EncodedString()
                    if message.settlementMethodDetails == nil {
                        logger.warning("handleTakerInformationMessage: private data in message was nil for \(message.swapID.uuidString)")
                    } else {
                        logger.notice("handleTakerInformationMessage: persistently storing private data in message for \(message.swapID.uuidString)")
                        try databaseService.updateSwapTakerPrivateSettlementMethodData(swapID: swapIDB64String, chainID: String(swap.chainID), data: message.settlementMethodDetails)
                        logger.notice("handleTakerInformationMessage: updating \(message.swapID.uuidString) with private data")
                        DispatchQueue.main.async {
                            swap.takerPrivateSettlementMethodData = message.settlementMethodDetails
                        }
                    }
                    logger.notice("handleTakerInformationMessage: updating \(message.swapID.uuidString) to \(SwapState.awaitingMakerInformation.asString)")
                    try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingMakerInformation.asString)
                    DispatchQueue.main.async {
                        swap.state = SwapState.awaitingMakerInformation
                    }
                    guard let makerKeyPair = try keyManagerService.getKeyPair(interfaceId: swap.makerInterfaceID) else {
                        throw SwapServiceError.unexpectedNilError(desc: "Could not find key pair for \(message.swapID.uuidString) while handling Taker Information Message")
                    }
                    guard let p2pService = p2pService else {
                        throw SwapServiceError.unexpectedNilError(desc: "p2pService was nil during handleTakerInformationMessage call for \(message.swapID.uuidString)")
                    }
                    logger.notice("handleTakerInformationMessage: sending for \(message.swapID.uuidString)")
                    if swap.makerPrivateSettlementMethodData == nil {
                        logger.warning("handleTakerInformationMessage: maker info is nil for \(swap.id.uuidString)")
                    }
                    try p2pService.sendMakerInformation(takerPublicKey: message.publicKey, makerKeyPair: makerKeyPair, swapID: swap.id, settlementMethodDetails: swap.makerPrivateSettlementMethodData)
                    logger.notice("handleTakerInformationMessage: sent for \(message.swapID.uuidString)")
                    switch swap.direction {
                    case .buy:
                        logger.notice("handleTakerInformationMessage: updating state of BUY swap \(message.swapID.uuidString) to \(SwapState.awaitingPaymentSent.asString)")
                        try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingPaymentSent.asString)
                        DispatchQueue.main.async {
                            swap.state = SwapState.awaitingPaymentSent
                        }
                    case .sell:
                        logger.notice("handleTakerInformationMessage: updating state of SELL swap \(message.swapID.uuidString) to \(SwapState.awaitingFilling.asString)")
                        try databaseService.updateSwapState(swapID: message.swapID.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingFilling.asString)
                        DispatchQueue.main.async {
                            swap.state = SwapState.awaitingFilling
                        }
                    }
                } else {
                    logger.notice("handleTakerInformation: detected own message for \(message.swapID.uuidString)")
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
            // We should only handle this message if we are the taker of the swap; otherwise, we are the maker and we would be handling our own message
            if swap.role == SwapRole.takerAndBuyer || swap.role == SwapRole.takerAndSeller {
                if senderInterfaceID != swap.makerInterfaceID {
                    logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) that was not sent by swap maker")
                    return
                }
                if recipientInterfaceID != swap.takerInterfaceID {
                    logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) with recipient interface ID \(recipientInterfaceID.base64EncodedString()) that doesn't match taker interface ID \(swap.takerInterfaceID.base64EncodedString())")
                    return
                }
                let swapIDB64String = message.swapID.asData().base64EncodedString()
                if message.settlementMethodDetails == nil {
                    logger.warning("handleMakerInformationMessage: private data in message was nil for \(message.swapID.uuidString)")
                } else {
                    logger.notice("handleMakerInformationMessage: persistently storing private data in message for \(message.swapID.uuidString)")
                    try databaseService.updateSwapMakerPrivateSettlementMethodData(swapID: swapIDB64String, chainID: String(swap.chainID), data: message.settlementMethodDetails)
                    logger.notice("handleMakerInformationMessage: updating \(message.swapID.uuidString) with private data")
                    DispatchQueue.main.async {
                        swap.makerPrivateSettlementMethodData = message.settlementMethodDetails
                    }
                }
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
                logger.notice("handleMakerInformationMessage: detected own message for \(message.swapID.uuidString)")
            }
        } else {
            logger.warning("handleMakerInformationMessage: got message for \(message.swapID.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `SwapService` of a `SwapFilledEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a swap, it ensures that the chain ID of the swap and the chain ID of `event` match. Then, if the role of the swap is `makerAndBuyer` or `takerAndSeller`, it logs a warning, since `SwapFilledEvent`s should not be emitted for such swaps. Otherwise, the role is `makerAndSeller` or `takerAndBuyer`, and this persistently sets the state of the swap to `awitingPaymentSent` and requiresFill to `false`, and then does the same to the `Swap` object on the main `DispatchQueue`.
     
     - Parameter event: The `SwapFilledEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or `SwapServiceError.nonmatchingChainIDError` if the chain ID of `event` and the chain ID of the `Swap` with the ID specified in `event` do not match.
     */
    func handleSwapFilledEvent(_ event: SwapFilledEvent) throws {
        logger.notice("handleSwapFilledEvent: handing for \(event.id.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleSwapFilledEvent call")
        }
        if let swap = swapTruthSource.swaps[event.id] {
            if swap.chainID != event.chainID {
                throw SwapServiceError.nonmatchingChainIDError(desc: "Chain ID of SwapFilledEvent did not match chain ID of Swap in handleSwapFilledEvent call. SwapFilledEvent.chainID: \(String(event.chainID)), Swap.chainID: \(String(swap.chainID)), SwapFilledEvent.id: \(event.id.uuidString)")
            }
            // At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
            switch (swap.role) {
            case .makerAndBuyer, .takerAndSeller:
                // If we are the maker of and buyer in or taker of and seller in the swap, no SwapFilled event should be emitted for that swap
                logger.warning("handleSwapFilledEvent: unexpectedly got event for \(event.id.uuidString) with role \(swap.role.asString)")
            case .makerAndSeller, .takerAndBuyer:
                logger.notice("handleSwapFilledEvent: handing for \(event.id.uuidString) as \(swap.role.asString)")
                // We have gotten confirmation that the fillSwap transaction has been confirmed, so we update the state of the swap to indicate that we are waiting for the buyer to send traditional currency payment
                let swapIDB64String = event.id.asData().base64EncodedString()
                try databaseService.updateSwapRequiresFill(swapID: swapIDB64String, chainID: String(event.chainID), requiresFill: false)
                try databaseService.updateSwapState(swapID: swapIDB64String, chainID: String(event.chainID), state: SwapState.awaitingPaymentSent.asString)
                swap.requiresFill = false
                DispatchQueue.main.async {
                    swap.state = .awaitingPaymentSent
                }
            }
        } else {
            logger.notice("handleSwapFilledEvent: \(event.id) not made or taken by user")
            return
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `PaymentSentEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a swap, it ensures that the chain ID of the swap and the chain ID of `event` match. Then it persistently sets the swap's `isPaymentSent` field to `true` and the state of the swap to `awaitingPaymentReceived`, and then does the same to the `Swap` object on the main `DispatchQueue`.
     
     - Parameter event: The `PaymentSentEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or `SwapServiceError.nonmatchingChainIDError` if if the chain ID of `event` and the chain ID of the `Swap` with the ID specified in `event` do not match.
     */
    func handlePaymentSentEvent(_ event: PaymentSentEvent) throws {
        logger.notice("handlePaymentSentEvent: handling for \(event.id.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handlePaymentSentEvent call")
        }
        if let swap = swapTruthSource.swaps[event.id] {
            if swap.chainID != event.chainID {
                throw SwapServiceError.nonmatchingChainIDError(desc: "Chain ID of PaymentSentEvent did not match chain ID of Swap in handlePaymentSentEvent call. PaymentSentEvent.chainID: \(String(event.chainID)), Swap.chainID: \(String(swap.chainID)), PaymentSentEvent.id: \(event.id.uuidString)")
            }
            // At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
            let swapIDB64String = event.id.asData().base64EncodedString()
            try databaseService.updateSwapIsPaymentSent(swapID: swapIDB64String, chainID: String(event.chainID), isPaymentSent: true)
            try databaseService.updateSwapState(swapID: swapIDB64String, chainID: String(event.chainID), state: SwapState.awaitingPaymentReceived.asString)
            swap.isPaymentSent = true
            DispatchQueue.main.async {
                swap.state = .awaitingPaymentReceived
            }
        } else {
            logger.notice("handlePaymentSentEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `PaymentReceivedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a swap, it ensures that the chain ID of the swap and the chain ID of `event` match. Then it persistently sets the swap's `isPaymentReceived` field to `true` and the state of the swap to `awaitingClosing`, and then does the same to the `Swap` object on the main `DispatchQueue`.
     
     - Parameter event: The `PaymentReceivedEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or `SwapServiceError.nonmatchingChainIDError` if if the chain ID of `event` and the chain ID of the `Swap` with the ID specified in `event` do not match.
     */
    func handlePaymentReceivedEvent(_ event: PaymentReceivedEvent) throws {
        logger.notice("handlePaymentReceivedEvent: handling for \(event.id.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handlePaymentReceivedEvent call")
        }
        if let swap = swapTruthSource.swaps[event.id] {
            if swap.chainID != event.chainID {
                throw SwapServiceError.nonmatchingChainIDError(desc: "Chain ID of PaymentReceivedEvent did not match chain ID of Swap in handlePaymentReceivedEvent call. PaymentReceivedEvent.chainID: \(String(event.chainID)), Swap.chainID: \(String(swap.chainID)), PaymentReceivedEvent.id: \(event.id.uuidString)")
            }
            // At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
            let swapIDB64String = event.id.asData().base64EncodedString()
            try databaseService.updateSwapIsPaymentReceived(swapID: swapIDB64String, chainID: String(event.chainID), isPaymentReceived: true)
            try databaseService.updateSwapState(swapID: swapIDB64String, chainID: String(event.chainID), state: SwapState.awaitingClosing.asString)
            swap.isPaymentReceived = true
            DispatchQueue.main.async {
                swap.state = .awaitingClosing
            }
        } else {
            logger.notice("handlePaymentReceivedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `BuyerClosedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a swap, it ensures that the chain ID of the swap and the chain ID of `event` match. Then it persistently sets the swap's `hasBuyerClosed` field to `true` and does the same to the `Swap` object. If the user of this interface is the buyer for the swap specified by `id`, this persistently sets the swaps state to `closed`, and does the same to the `Swap` object on the main `DispatchQueue`.
     
     - Parameter event: The `BuyerClosedEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or `SwapServiceError.nonmatchingChainIDError` if the chain ID of `event` and the chain ID of the `Swap` with the ID specified in `event` do not match.
     */
    func handleBuyerClosedEvent(_ event: BuyerClosedEvent) throws {
        logger.notice("handleBuyerClosedEvent: handling for \(event.id.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleBuyerClosedEvent call")
        }
        if let swap = swapTruthSource.swaps[event.id] {
            if swap.chainID != event.chainID {
                throw SwapServiceError.nonmatchingChainIDError(desc: "Chain ID of BuyerClosedEvent did not match chain ID of Swap in BuyerClosedEvent call. BuyerClosedEvent.chainID: \(String(event.chainID)), Swap.chainID: \(String(swap.chainID)), BuyerClosedEvent.id: \(event.id.uuidString)")
            }
            // At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
            let swapIDB64String = event.id.asData().base64EncodedString()
            try databaseService.updateSwapHasBuyerClosed(swapID: swapIDB64String, chainID: String(event.chainID), hasBuyerClosed: true)
            swap.hasBuyerClosed = true
            // If the user of this interface is the buyer, than this is their BuyerClosed event. Therefore we should update the state of the swap to show that the user has closed it.
            if swap.role == .makerAndBuyer || swap.role == .takerAndBuyer {
                logger.notice("handleBuyerClosedEvent: setting state of \(event.id.uuidString) to closed")
                try databaseService.updateSwapState(swapID: swapIDB64String, chainID: String(event.chainID), state: SwapState.closed.asString)
                DispatchQueue.main.async {
                    swap.state = .closed
                }
            }
        } else {
            logger.notice("handleBuyerClosedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `SellerClosedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a swap, it ensures that the chain ID of the swap and the chain ID of `event` match. Then it persistently sets the swap's `hasSellerClosed` field to `true` and does the same to the `Swap` object. If the user of this interface is the seller for the swap specified by `id`, this persistently sets the swaps state to `closed`, and does the same to the `Swap` object on the main `DispatchQueue`.
     
     - Parameter event: The `SellerClosedEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or `SwapServiceError.nonmatchingChainIDError` if if the chain ID of `event` and the chain ID of the `Swap` with the ID specified in `event` do not match.
     */
    func handleSellerClosedEvent(_ event: SellerClosedEvent) throws {
        logger.notice("handleSellerClosedEvent: handling for \(event.id.uuidString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleSellerClosedEvent call")
        }
        if let swap = swapTruthSource.swaps[event.id] {
            if swap.chainID != event.chainID {
                throw SwapServiceError.nonmatchingChainIDError(desc: "Chain ID of SellerClosedEvent did not match chain ID of Swap in SellerClosedEvent call. SellerClosedEvent.chainID: \(String(event.chainID)), Swap.chainID: \(String(swap.chainID)), SellerClosedEvent.id: \(event.id.uuidString)")
            }
            // At this point, we have ensured that the chain ID of the event and the swap match, so we can proceed safely
            let swapIDB64String = event.id.asData().base64EncodedString()
            try databaseService.updateSwapHasSellerClosed(swapID: swapIDB64String, chainID: String(event.chainID), hasSellerClosed: true)
            swap.hasSellerClosed = true
            // If the user of this interface is the seller, than this is their SellerClosed event. Therefore we should update the state of the swap to show that the user has closed it.
            if swap.role == .makerAndSeller || swap.role == .takerAndSeller {
                logger.notice("handleSellerClosedEvent: setting state of \(event.id.uuidString) to closed")
                try databaseService.updateSwapState(swapID: swapIDB64String, chainID: String(event.chainID), state: SwapState.closed.asString)
                DispatchQueue.main.async {
                    swap.state = .closed
                }
            }
        } else {
            logger.notice("handleSellerClosedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
}

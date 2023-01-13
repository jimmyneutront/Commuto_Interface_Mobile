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
import web3swift

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
        DispatchQueue.main.sync {
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
        DispatchQueue.main.sync {
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
                // try databaseService.updateSwapState(swapID: swapIDString, chainID: String(filledSwap.chainID), state: SwapState.fillSwapTransactionBroadcast.asString)
                try databaseService.updateSwapRequiresFill(swapID: swapIDString, chainID: String(filledSwap.chainID), requiresFill: false)
                // This is not a @Published property, so we can update it from a background thread
                filledSwap.requiresFill = false
            }.done(on: DispatchQueue.main) { _, filledSwap in
                // filledSwap.state = .fillSwapTransactionBroadcast
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("fillSwap: encountered error during call for \(swapToFill.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to fill a maker-as-seller swap made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateSwapForFilling` and then calls `BlockchainService.createAPproveTransferTransaction`, passing the stablecoin contract address, the CommutoSwap contract address and the taken swap amount, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameter swapToFill: The `Swap` to be filled, for which this is creating a token transfer approval transaction
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of approving a token transfer of the taken swap amount of `swapToFill`.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createApproveTokenTransferToFillSwapTransaction(swapToFill: Swap) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createApproveTokenTransferToFillSwapTransaction: creating for \(swapToFill.id) for amount \(String(swapToFill.takenSwapAmount))")
                do {
                    try validateSwapForFilling(swap: swapToFill)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during createApproveTokenTransferToFillSwapTransaction call"))
                    return
                }
                blockchainService.createApproveTransferTransaction(tokenAddress: swapToFill.stablecoin, spender: blockchainService.commutoSwapAddress, amount: swapToFill.takenSwapAmount).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to call [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to fill a maker-as-seller swap for which the user of this interface is the maker.
     
     On the global `DispatchQueue`, this calls `validateSwapForFilling`, and then creates another `EthereumTransaction` to approve a transfer equal to `swapToFill`'s taken swap amount, and then ensures that the data of this transaction matches the data of `approveTokenTransferToFillSwapTransaction`. (If they do not match, then `approveTokenTransferToFillSwapTransaction` was not created with the data supplied to this function.) Then this signs `approveTokenTransferToFillSwapTransaction` and creates  a `BlockchainTransaction` to wrap it. Then this persistently stores the token transfer approval data for said `BlockchainTransaction` and persistently updates the token transfer approval state of `swapToFill` to `TokenTransferApprovalState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Swap.approvingToFillState` property of `swapToFill` to `TokenTransferApprovalState.sendingTransaction` and sets the `Swap.approvingToFillTransaction` property of `swapToFill` to said `BlockchainTransaction`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the approving to fill state of `swapToTake` to `TokenTransferApprovalState.awaitingTransactionConfirmation`. Then, on the main `DispatchQueue`, this updates the `Swap.approvingToFillState` property of `swapToFill` to `TokenTransferApprovalState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - swapToFill: The swap that will be filled, for which this is approving a token transfer.
        - approveTokenTransferToFillSwapTransaction: An optional `EthereumTransaction` that can approve a token transfer for the proper amount.
     
     - Returns: An empty `Promise` that will be fulfilled when the token transfer is approved.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil` or if `approveTokenTransferToFillSwapTransaction` is `nil` or a `SwapServiceError.nonmatchingDataError` if the data of `approveTokenTransferToFillSwapTransaction` does not match that of the transaction this function creates using the supplied arguments. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func approveTokenTransferToFillSwap(
        swapToFill: Swap,
        approveTokenTransferToFillSwapTransaction: EthereumTransaction?
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<EthereumTransaction>() { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("approveTokenTransferToFillSwap: validating for \(swapToFill.id.uuidString)")
                    do {
                        try validateSwapForFilling(swap: swapToFill)
                    } catch {
                        seal.reject(error)
                    }
                    logger.notice("approveTokenTransferToFillSwap: recreating EthereumTransaction to approve transfer of \(String(swapToFill.takenSwapAmount)) tokens at contract \(swapToFill.stablecoin.address) for \(swapToFill.id.uuidString)")
                    guard let blockchainService = blockchainService else {
                        seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToFillSwap call for \(swapToFill.id.uuidString)"))
                        return
                    }
                    return blockchainService.createApproveTransferTransaction(tokenAddress: swapToFill.stablecoin, spender: blockchainService.commutoSwapAddress, amount: swapToFill.takenSwapAmount).pipe(to: seal.resolve)
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction -> Promise<BlockchainTransaction> in
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToFillSwap call for \(swapToFill.id.uuidString)")
                }
                guard var approveTokenTransferToFillSwapTransaction = approveTokenTransferToFillSwapTransaction else {
                    throw SwapServiceError.unexpectedNilError(desc: "Transaction was nil during approveTokenTransferToFillSwap call for \(swapToFill.id.uuidString)")
                }
                guard recreatedTransaction.data == approveTokenTransferToFillSwapTransaction.data else {
                    throw SwapServiceError.nonmatchingDataError(desc: "Data of approveTokenTransferToFillSwap did not match that of transaction created with supplied data for \(swapToFill.id.uuidString)")
                }
                logger.notice("approveTokenTransferToFillSwap: signing transaction for \(swapToFill.id.uuidString)")
                try blockchainService.signTransaction(&approveTokenTransferToFillSwapTransaction)
                let blockchainTransactionForApprovingTransfer = try BlockchainTransaction(transaction: approveTokenTransferToFillSwapTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .approveTokenTransferToFillSwap)
                let dateString = DateFormatter.createDateString(blockchainTransactionForApprovingTransfer.timeOfCreation)
                logger.notice("approveTokenTransferToFillSwap: persistently storing approve transfer data for \(swapToFill.id.uuidString), including tx hash \(blockchainTransactionForApprovingTransfer.transactionHash)")
                try databaseService.updateSwapApproveToFillData(swapID: swapToFill.id.asData().base64EncodedString(), _chainID: String(swapToFill.chainID), transactionHash: blockchainTransactionForApprovingTransfer.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForApprovingTransfer.latestBlockNumberAtCreation))
                logger.notice("approveTokenTransferToFillSwap: persistently updating approvingToFillState for \(swapToFill.id.uuidString) to sendingTransaction")
                try databaseService.updateSwapApproveToFillState(swapID: swapToFill.id.asData().base64EncodedString(), _chainID: String(swapToFill.chainID), state: TokenTransferApprovalState.sendingTransaction.asString)
                logger.notice("approveTokenTransferToFillSwap: updating approvingToFillState for \(swapToFill.id.uuidString) to sendingTransaction and storing tx \(blockchainTransactionForApprovingTransfer.transactionHash) in swap")
                return Promise.value(blockchainTransactionForApprovingTransfer)
            }.get(on: DispatchQueue.main) { blockchainTransactionForApprovingTransfer in
                swapToFill.approvingToFillState = .sendingTransaction
                swapToFill.approvingToFillTransaction = blockchainTransactionForApprovingTransfer
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("approveTokenTransferToFillSwap: persistently updating approvingToFillState of \(swapToFill.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateSwapApproveToFillState(swapID: swapToFill.id.asData().base64EncodedString(), _chainID: String(swapToFill.chainID), state: TokenTransferApprovalState.awaitingTransactionConfirmation.asString)
                logger.notice("approveTokenTransferToFillSwap: updating approvingToFillState to awaitingTransactionConfirmation for \(swapToFill.id.uuidString)")
            }.get(on: DispatchQueue.main) { _ in
                swapToFill.approvingToFillState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("approveTokenTransferToFillSwap: encountered error, setting approvingToFillState of \(swapToFill.id.uuidString) to error and setting approvingToFill error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the approving to fill state isn't updated to error, then when the app restarts, we will check the approving to fill transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateSwapApproveToFillState(swapID: swapToFill.id.asData().base64EncodedString(), _chainID: String(swapToFill.chainID), state: TokenTransferApprovalState.error.asString)
                } catch {}
                swapToFill.approvingToFillError = error
                DispatchQueue.main.async {
                    swapToFill.approvingToFillState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will fill a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap) made by the user of this interface.
     
     This calls `validateSwapForFilling`, and then calls `BlockchainService.createFillSwapTransaction`, passing the `Swap.id` property of `offer`.
     
     - Parameter offer: The `Swap` to be opened.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of filling `swap`.
     
     - Throws: An `OfferServiceError.unexpectedNilError` of `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func createFillSwapTransaction(swap: Swap) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createFillSwapTransaction: creating for \(swap.id.uuidString)")
                do {
                    try validateSwapForFilling(swap: swap)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during createFillSwapTransaction call for \(swap.id.uuidString)"))
                    return
                }
                blockchainService.createFillSwapTransaction(id: swap.id).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to fill a maker-as-seller [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateSwapForFilling`, and then creates another `EthereumTransaction` to fill `swap` and ensures that the data of this transaction matches the data of `swapFillingTransaction`. (If they do not match, then `swapFillingTransaction` was not created with the data contained in `swap`.) Then this signs `swapFillingTransaction` and creates a `BlockchainTransaction` to wrap it. then this persistently stores the swap filling data for said `BlockchainTransaction`, and persistently updates the swap filling state of `swap` to `FillingSwapState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Swap.fillingSwapState` property of `swap` to `FillingSwapState.sendingTransaction` and sets the `Swap.swapFillingTransaction` property of `swap` to said `BlockchainTransaction`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the state of `swap` to `SwapState.fillSwapTransactionSent` and the swap filling state of `Swap` to `SwapFillingState.awaitingTransactionConfirmation`. Then, on the main `DispatchQueue`, this updates the `Swap.state` property of `swap` to `SwapState.fillSwapTransactionSent` and the `Swap.fillingSwapState` property of `swap` to `FillingSwapState.awaitingTransactionConfirmation`.
     
     If this catches an error, it persistently updates the filling swap state of `swap` to `FillingSwapState.exception`, sets the `Swap.fillingSwapError` property of `swap` to the caught error, and then, on the main `DispatchQueue`, sets the `Swap.fillingSwapState` property of `swap` to `FillingSwapState.error`.
     
     - Parameters:
        - swap: The `Swap` to fill.
        - swapFillingTransaction: An optional `EthereumTransaction` that can fill `swap`.
     
     - Returns: An empty `Promise` that will be fulfilled when `swap` is filled.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `swapFillingTransaction` is `nil` or if `blockchainService` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `swapFillingTransaction` does not match that of the transaction this function creates using `swap`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func fillSwap(swap: Swap, swapFillingTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<EthereumTransaction> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("fillSwap: filling \(swap.id.uuidString)")
                    do {
                        try validateSwapForFilling(swap: swap)
                    } catch {
                        seal.reject(error)
                    }
                    logger.notice("fillSwap: recreating EthereumTransaction to fill \(swap.id.uuidString) to ensure swapFillingTransaction was created with the contents of swap")
                    guard let blockchainService = blockchainService else {
                        seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during fillSwap call for \(swap.id.uuidString)"))
                        return
                    }
                    blockchainService.createFillSwapTransaction(id: swap.id).pipe(to: seal.resolve)
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction -> Promise<BlockchainTransaction> in
                guard var swapFillingTransaction = swapFillingTransaction else {
                    throw SwapServiceError.unexpectedNilError(desc: "Transaction was nil during fillSwap call for \(swap.id.uuidString)")
                }
                guard recreatedTransaction.data == swapFillingTransaction.data else {
                    throw SwapServiceError.unexpectedNilError(desc: "Data of swapFillingTransaction did not match that of transaction created with swap \(swap.id.uuidString)")
                }
                guard let blockchainService = blockchainService else {
                    throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during fillSwap call for \(swap.id.uuidString)")
                }
                logger.notice("fillSwap: signing transaction for \(swap.id.uuidString)")
                try blockchainService.signTransaction(&swapFillingTransaction)
                let blockchainTransactionForSwapFilling = try BlockchainTransaction(transaction: swapFillingTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .fillSwap)
                let dateString = DateFormatter.createDateString(blockchainTransactionForSwapFilling.timeOfCreation)
                logger.notice("fillSwap: persistently storing swap filling data for \(swap.id.uuidString), including tx hash \(blockchainTransactionForSwapFilling.transactionHash)")
                try databaseService.updateFillingSwapData(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), transactionHash: blockchainTransactionForSwapFilling.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForSwapFilling.latestBlockNumberAtCreation))
                logger.notice("fillSwap: persistently updating fillingSwapState for \(swap.id.uuidString) to \(FillingSwapState.sendingTransaction.asString)")
                try databaseService.updateFillingSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: FillingSwapState.sendingTransaction.asString)
                logger.notice("fillSwap: updating fillingSwapState to sendingTransaction and storing tx \(blockchainTransactionForSwapFilling.transactionHash) in \(swap.id.uuidString)")
                return Promise.value(blockchainTransactionForSwapFilling)
            }.get(on: DispatchQueue.main) { blockchainTransactionForSwapFilling in
                swap.swapFillingTransaction = blockchainTransactionForSwapFilling
                swap.fillingSwapState = .sendingTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] swapFillingBlockchainTransaction -> Promise<TransactionSendingResult> in
                logger.notice("fillSwap: sending \(swapFillingBlockchainTransaction.transactionHash) for \(swap.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during fillSwap call for \(swap.id.uuidString)")
                }
                return blockchainService.sendTransaction(swapFillingBlockchainTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("fillSwap: persistently updating state of \(swap.id.uuidString) to \(SwapState.fillSwapTransactionSent.asString)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.fillSwapTransactionSent.asString)
                logger.notice("fillSwap: persistently updating fillingSwapState of \(swap.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateFillingSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: FillingSwapState.awaitingTransactionConfirmation.asString)
                logger.notice("fillSwap: updating state to \(SwapState.fillSwapTransactionSent.asString) and fillingSwapState to awaitingTransactionConfirmation for \(swap.id.uuidString)")
            }.get(on: DispatchQueue.main) { _ in
                swap.state = SwapState.fillSwapTransactionSent
                swap.fillingSwapState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("fillSwap: encountered error while filling \(swap.id.uuidString), setting fillingSwapState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the filling swap state isn't updated to error, then when the app restarts, we will check the swap filling transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateFillingSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: FillingSwapState.error.asString)
                } catch {}
                swap.fillingSwapError = error
                DispatchQueue.main.async {
                    swap.fillingSwapState = .error
                }
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
     Attempts to create an `EthereumTransaction` that will call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) for which the user of this interface is the buyer.
     
     On the global `DispatchQueue`, this calls `validateSwapForReportingPaymentSent`, and then `BlockchainService.createReportPaymentSentTransaction`, passing the `Swap.id` and `Swap.chainID` properties of `swap`, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameter swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of calling [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`.
     
     - Throws: An `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createReportPaymentSentTransaction(swap: Swap) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createReportPaymentSentTransaction: creating for \(swap.id.uuidString)")
                do {
                    try validateSwapForReportingPaymentSent(swap: swap)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during createReportPaymentSentTransaction call"))
                    return
                }
                blockchainService.createReportPaymentSentTransaction(swapID: swap.id, chainID: swap.chainID).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) in which the user of this interface is the buyer.
     
     On the global `DispatchQueue`, this calls `validateSwapForReportingPaymentSent`, and ensures that `reportPaymentSentTransaction` is not `nil`. Then it signs `reportPaymentSentTransaction`, creates a `BlockchainTransaction` to wrap it, determines the transaction hash, persistently stores the transaction hash and persistently updates the `Swap.reportingPaymentSentState` of `swap` to `ReportingPaymentSentState.sendingTransaction`. Then, on the main `DispatchQueue`, this stores the transaction hash in `swap` and sets `swap`'s `Swap.reportingPaymentSentState` property to `ReportingPaymentSentState.sendingTransaction`. Then, on the global `DispatchQueue` it sends the `BlockchainTransaction`-wrapped `reportPaymentSentTransaction` to the blockchain. Once a response is received, this persistently updates the `Swap.reportingPaymentSentState` of `swap` to `ReportingPaymentSentState.awaitingTransactionConfirmation` and persistently updates the `Swap.state` property of `swap` to `SwapState.reportPaymentSentTransactionBroadcast`. Then, on the main `DispatchQueue`, this sets the value of `swap`'s `Swap.reportingPaymentSentState` to `ReportingPaymentSentState.awaitingTransactionConfirmation` and the value of `swap`'s `Swap.state` to `SwapState.reportPaymentSentTransactionBroadcast`.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
        - reportPaymentSentTransaction: An optional `EthereumTransaction` that can call [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for `swap`.
     
     - Returns: An empty `Promise` that will be fulfilled when [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) is called for `swap`.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `reportPaymentSentTransaction` or `blockchainService` are `nil`. Because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func reportPaymentSent(swap: Swap, reportPaymentSentTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<(BlockchainTransaction, BlockchainService)> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("reportPaymentSent: checking reporting is possible for \(swap.id.uuidString)")
                    do {
                        try validateSwapForReportingPaymentSent(swap: swap)
                    } catch {
                        seal.reject(error)
                    }
                    do {
                        guard var reportPaymentSentTransaction = reportPaymentSentTransaction else {
                            throw SwapServiceError.unexpectedNilError(desc: "Transaction was nil during reportPaymentSent call for \(swap.id.uuidString)")
                        }
                        guard let blockchainService = blockchainService else {
                            throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during reportPaymentSent call for \(swap.id.uuidString)")
                        }
                        logger.notice("reportPaymentSent: signing transaction for \(swap.id.uuidString)")
                        try blockchainService.signTransaction(&reportPaymentSentTransaction)
                        let blockchainTransactionForReportingPaymentSent = try BlockchainTransaction(transaction: reportPaymentSentTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .reportPaymentSent)
                        let dateString = DateFormatter.createDateString(blockchainTransactionForReportingPaymentSent.timeOfCreation)
                        logger.notice("reportPaymentSent: persistently storing report payment sent data for \(swap.id.uuidString), including tx hash \(blockchainTransactionForReportingPaymentSent.transactionHash)")
                        try databaseService.updateReportPaymentSentData(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), transactionHash: blockchainTransactionForReportingPaymentSent.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForReportingPaymentSent.latestBlockNumberAtCreation))
                        logger.notice("reportPaymentSent: persistently updating reportingPaymentSentState for \(swap.id.uuidString) to sendingTransaction")
                        try databaseService.updateReportPaymentSentState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentSentState.sendingTransaction.asString)
                        logger.notice("reportPaymentSent: updating reportingPaymentSentState for \(swap.id.uuidString) to sendingTransaction and storing tx hash \(blockchainTransactionForReportingPaymentSent.transactionHash) in swap")
                        seal.fulfill((blockchainTransactionForReportingPaymentSent, blockchainService))
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { reportPaymentSentTransaction, _ in
                swap.reportingPaymentSentState = .sendingTransaction
                swap.reportPaymentSentTransaction = reportPaymentSentTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { reportPaymentSentTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("reportPaymentSent: sending \(reportPaymentSentTransaction.transactionHash) for \(swap.id.uuidString)")
                return blockchainService.sendTransaction(reportPaymentSentTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("reportPaymentSent: persistently updating reportingPaymentSentState of \(swap.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateReportPaymentSentState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentSentState.awaitingTransactionConfirmation.asString)
                logger.notice("reportPaymentSent: persistently updating state of \(swap.id.uuidString) to reportPaymentSentTransactionBroadcast")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.reportPaymentSentTransactionBroadcast.asString)
                logger.notice("reportPaymentSent: updating reportingPaymentSentState for \(swap.id.uuidString) to awaitingTransactionConfirmation and state to reportPaymentSentTransactionBroadcast")
            }.get(on: DispatchQueue.main) { _ in
                swap.reportingPaymentSentState = .awaitingTransactionConfirmation
                swap.state = .reportPaymentSentTransactionBroadcast
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("reportPaymentSent: encountered error while reporting for \(swap.id.uuidString), setting reportingPaymentSentState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the reporting payment sent state isn't updated to error, then when the app restarts, we will check the reporting payment sent transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateReportPaymentSentState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentSentState.error.asString)
                } catch {}
                swap.reportingPaymentSentError = error
                DispatchQueue.main.async {
                    swap.reportingPaymentSentState = .error
                }
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
     Attempts to create an `EthereumTransaction` that will call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap).
     
     On the global `DispatchQueue`, this calls `validateSwapForReportingPaymentReceived`, and then `BlockchainService.createReportPaymentReceivedTransaction`, passing the `Swap.id` and `Swap.chainID` properties of `swap`, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameter swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of calling [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`.
     
     - Throws: An `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createReportPaymentReceivedTransaction(swap: Swap) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createReportPaymentReceivedTransaction: creating for \(swap.id.uuidString)")
                do {
                    try validateSwapForReportingPaymentReceived(swap: swap)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during createReportPaymentReceivedTransaction call"))
                    return
                }
                blockchainService.createReportPaymentReceivedTransaction(swapID: swap.id, chainID: swap.chainID).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) in which the user of this interface is the seller.
     
     On the global `DispatchQueue`, this calls `validateSwapForReportingPaymentReceived`, and ensures that `reportPaymentReceivedTransaction` is not `nil`. Then it signs `reportPaymentReceivedTransaction`, creates a `BlockchainTransaction` to wrap it, determines the transaction hash, persistently stores the transaction hash and persistently updates the `Swap.reportingPaymentReceivedState` of `swap` to `ReportingPaymenReceivedState.sendingTransaction`. Then, on the main `DispatchQueue`, this stores the transaction hash in `swap` and sets `swap`'s `Swap.reportingPaymentReceivedState` property to `ReportingPaymentReceivedState.sendingTransaction`. Then, on the global `DispatchQueue` it sends the `BlockchainTransaction`-wrapped `reportPaymentReceivedTransaction` to the blockchain. Once a response is received, this persistently updates the `Swap.reportingPaymentReceivedState` of `swap` to `ReportingPaymentReceivedState.awaitingTransactionConfirmation` and persistently updates the `Swap.state` property of `swap` to `SwapState.reportPaymentReceivedTransactionBroadcast`. Then, on the main `DispatchQueue`, this sets the value of `swap`'s `Swap.reportingPaymentReceivedState` to `ReportingPaymentReceivedState.awaitingTransactionConfirmation` and the value of `swap`'s `Swap.state` to `SwapState.reportPaymentReceivedTransactionBroadcast`.
     
     - Parameters:
        - swap: The `Swap` for which [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) will be called.
        - reportPaymentReceivedTransaction: An optional `EthereumTransaction` that can call [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) for `swap`.
     
     - Returns: An empty `Promise` that will be fulfilled when [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received) is called for `swap`.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `reportPaymenReceivedTransaction` or `blockchainService` are `nil`. Because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func reportPaymentReceived(swap: Swap, reportPaymentReceivedTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<(BlockchainTransaction, BlockchainService)> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("reportPaymentReceived: checking reporting is possible for \(swap.id.uuidString)")
                    do {
                        try validateSwapForReportingPaymentReceived(swap: swap)
                    } catch {
                        seal.reject(error)
                    }
                    do {
                        guard var reportPaymentReceivedTransaction = reportPaymentReceivedTransaction else {
                            throw SwapServiceError.unexpectedNilError(desc: "Transaction was nil during reportPaymentReceived call for \(swap.id.uuidString)")
                        }
                        guard let blockchainService = blockchainService else {
                            throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during reportPaymentReceived call for \(swap.id.uuidString)")
                        }
                        logger.notice("reportPaymentReceived: signing transaction for \(swap.id.uuidString)")
                        try blockchainService.signTransaction(&reportPaymentReceivedTransaction)
                        let blockchainTransactionForReportingPaymentReceived = try BlockchainTransaction(transaction: reportPaymentReceivedTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .reportPaymentReceived)
                        let dateString = DateFormatter.createDateString(blockchainTransactionForReportingPaymentReceived.timeOfCreation)
                        logger.notice("reportPaymentReceived: persistently storing report payment received data for \(swap.id.uuidString), including tx hash \(blockchainTransactionForReportingPaymentReceived.transactionHash)")
                        try databaseService.updateReportPaymentReceivedData(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), transactionHash: blockchainTransactionForReportingPaymentReceived.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForReportingPaymentReceived.latestBlockNumberAtCreation))
                        logger.notice("reportPaymentReceived: persistently updating reportingPaymentReceivedState for \(swap.id.uuidString) to sendingTransaction")
                        try databaseService.updateReportPaymentReceivedState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentReceivedState.sendingTransaction.asString)
                        logger.notice("reportPaymentReceived: updating reportingPaymentReceivedState for \(swap.id.uuidString) to sendingTransaction and storing tx hash \(blockchainTransactionForReportingPaymentReceived.transactionHash) in swap")
                        seal.fulfill((blockchainTransactionForReportingPaymentReceived, blockchainService))
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { reportPaymentReceivedTransaction, _ in
                swap.reportingPaymentReceivedState = .sendingTransaction
                swap.reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { reportPaymentReceivedTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("reportPaymentReceived: sending \(reportPaymentReceivedTransaction.transactionHash) for \(swap.id.uuidString)")
                return blockchainService.sendTransaction(reportPaymentReceivedTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("reportPaymentReceived: persistently updating reportingPaymentReceivedState of \(swap.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateReportPaymentReceivedState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentReceivedState.awaitingTransactionConfirmation.asString)
                logger.notice("reportPaymentReceived: persistently updating state of \(swap.id.uuidString) to reportPaymentReceivedTransactionBroadcast")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.reportPaymentReceivedTransactionBroadcast.asString)
                logger.notice("reportPaymentReceived: updating reportingPaymentReceivedState for \(swap.id.uuidString) to awaitingTransactionConfirmation and state to reportPaymentReceivedTransactionBroadcast")
            }.get(on: DispatchQueue.main) { _ in
                swap.reportingPaymentReceivedState = .awaitingTransactionConfirmation
                swap.state = .reportPaymentReceivedTransactionBroadcast
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("reportPaymentReceived: encountered error while reporting for \(swap.id.uuidString), setting reportingPaymentReceivedState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the reporting payment received state isn't updated to error, then when the app restarts, we will check the reporting payment received transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateReportPaymentReceivedState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentReceivedState.error.asString)
                } catch {}
                swap.reportingPaymentReceivedError = error
                DispatchQueue.main.async {
                    swap.reportingPaymentReceivedState = .error
                }
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
     Attempts to create an `EthereumTransaction` that will call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) involving the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateSwapForClosing`, and then this calls `BlockchainService.createCloseSwapTransaction`, passing the `Swap.id` and `Swap.chainID` properties of `swap`, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameter swap: The `Swap` for which [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent) will be called.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for `swap`.
     
     - Throws: An `SwapServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createCloseSwapTransaction(swap: Swap) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createCloseSwapTransaction: creating for \(swap.id.uuidString)")
                do {
                    try validateSwapForClosing(swap: swap)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during createCloseSwapTransaction call"))
                    return
                }
                blockchainService.createCloseSwapTransaction(swapID: swap.id, chainID: swap.chainID).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for a [Swap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#swap) involving the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateSwapForClosing`, and ensures that `closeSwapTransaction` is not `nil`. Then it signs `closeSwapTransaction`, creates a `BlockchainTransaction` to wrap it, determines the transaction hash, persistently stores the transaction hash and persistently updates the `Swap.closingSwapState` of `swap` to `ClosingSwapState.sendingTransaction`. Then, on the main `DispatchQueue`, this stores the transaction hash in `swap` and sets `swap`'s `Swap.closingSwapState` property to `ClosingSwapState.sendingTransaction`. Then, on the global `DispatchQueue` it sends the `BlockchainTransaction`-wrapped `closingSwapTransaction` to the blockchain. Once a response is received, this persistently updates the `Swap.closingSwapState` of `swap` to `ClosingSwapState.awaitingTransactionConfirmation` and persistently updates the `Swap.state` property of `swap` to `SwapState.closeSwapTransactionBroadcast`. Then, on the main `DispatchQueue`, this sets the value of `swap`'s `Swap.closingSwapState` to `ClosingSwapState.awaitingTransactionConfirmation` and the value of `swap`'s `Swap.state` to `SwapState.closeSwapTransactionBroadcast`.
     
     - Parameters:
        - swap: The `Swap` for which [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) will be called.
        - reportPaymentReceivedTransaction: An optional `EthereumTransaction` that can call [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) for `swap`.
     
     - Returns: An empty `Promise` that will be fulfilled when [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap) is called for `swap`.
     
     - Throws: A `SwapServiceError.unexpectedNilError` if `closeSwapTransaction` or `blockchainService` are `nil`. Because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func closeSwap(swap: Swap, closeSwapTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<(BlockchainTransaction, BlockchainService)> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("closeSwap: checking closing is possible for \(swap.id.uuidString)")
                    do {
                        try validateSwapForClosing(swap: swap)
                    } catch {
                        seal.reject(error)
                    }
                    do {
                        guard var closeSwapTransaction = closeSwapTransaction else {
                            throw SwapServiceError.unexpectedNilError(desc: "Transaction was nil during closeSwap call for \(swap.id.uuidString)")
                        }
                        guard let blockchainService = blockchainService else {
                            throw SwapServiceError.unexpectedNilError(desc: "blockchainService was nil during closeSwap call for \(swap.id.uuidString)")
                        }
                        logger.notice("closeSwap: signing transaction for \(swap.id.uuidString)")
                        try blockchainService.signTransaction(&closeSwapTransaction)
                        let blockchainTransactionForClosingSwap = try BlockchainTransaction(transaction: closeSwapTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .closeSwap)
                        let dateString = DateFormatter.createDateString(blockchainTransactionForClosingSwap.timeOfCreation)
                        logger.notice("closeSwap: persistently storing close swap data for \(swap.id.uuidString), including tx hash \(blockchainTransactionForClosingSwap.transactionHash)")
                        try databaseService.updateCloseSwapData(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), transactionHash: blockchainTransactionForClosingSwap.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForClosingSwap.latestBlockNumberAtCreation))
                        logger.notice("closeSwap: persistently updating closeSwapState for \(swap.id.uuidString) to sendingTransaction")
                        try databaseService.updateCloseSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ClosingSwapState.sendingTransaction.asString)
                        logger.notice("closeSwap: updating closeSwapState for \(swap.id.uuidString) to sendingTransaction and storing tx hash \(blockchainTransactionForClosingSwap.transactionHash) in swap")
                        seal.fulfill((blockchainTransactionForClosingSwap, blockchainService))
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { closeSwapTransaction, _ in
                swap.closingSwapState = .sendingTransaction
                swap.closeSwapTransaction = closeSwapTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { closeSwapTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("closeSwap: sending \(closeSwapTransaction.transactionHash) for \(swap.id.uuidString)")
                return blockchainService.sendTransaction(closeSwapTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("closeSwap: persistently updating closeingSwapState of \(swap.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateCloseSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ClosingSwapState.awaitingTransactionConfirmation.asString)
                logger.notice("closeSwap: persistently updating state of \(swap.id.uuidString) to closeSwapTransactionBroadcast")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.closeSwapTransactionBroadcast.asString)
                logger.notice("closeSwap: updating closingSwapStateState for \(swap.id.uuidString) to awaitingTransactionConfirmation and state to closeSwapTransactionBroadcast")
            }.get(on: DispatchQueue.main) { _ in
                swap.closingSwapState = .awaitingTransactionConfirmation
                swap.state = .closeSwapTransactionBroadcast
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("closeSwap: encountered error while closing \(swap.id.uuidString), setting closingSwapState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the closing swap state isn't updated to error, then when the app restarts, we will check the closing swap transaction, and discover and handle the error then.
                do {
                    try databaseService.updateCloseSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ClosingSwapState.error.asString)
                } catch {}
                swap.closingSwapError = error
                DispatchQueue.main.async {
                    swap.closingSwapState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    /**
     The function called by `BlockchainService` in order to notify `SwapService` that a monitored swap-related `BlockchainTransaction` has failed (either has been confirmed and failed, or has been dropped.)
     
     If `transaction` is of type `BlockchainTransactionType.approveTokenTransferToFillSwap`, then this finds the swap with the corresponding approving to fill transaction hash, persistently updates its approving to fill state to `TokenTransferApprovalState.error`, and on the main `DispatchQueue` sets its `Swap.approvingToFillError` to `error` and updates its `Swap.approvingToFillState` property to `TokenTransferApprovalState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.fillSwap`, then this finds the swap with the corresponding swap filling transaction hash, persistently updates its state to `SwapState.awaitingFilling`, persistently updates its swap filling state to `FillingSwapState.error` and on the main `DispatchQueue` sets the `Swap.state` property to `SwapState.awaitingFilling`, the `Swap.fillingSwapError` property to `error`, and the `Swap.fillingSwapState` to `FillingSwapState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.reportPaymentSent`, then this finds the swap with the corresponding reporting payment sent transaction hash, persistently updates its reporting payment sent state to `ReportingPaymentSentState.error` and its state to `SwapState.awaitingPaymentSent`, and on the main `DispatchQueue` sets its `Swap.reportingPaymentSentError` to `error`, updates its `Swap.reportingPaymentSentState` property to `ReportingPaymentSentState.error`, and updates its `Swap.state` property to `SwapState.awaitingPaymentSent`.
     
     If `transaction` is of type `BlockchainTransactionType.reportPaymentReceived`, then this finds the swap with the corresponding reporting payment received transaction hash, persistently updates its reporting payment received state to `ReportingPaymentReceivedState.error` and its state to `SwapState.awaitingPaymentReceived`, and on the main `DispatchQueue` sets its `Swap.reportingPaymentReceivedError` to `error`, updates its `Swap.reportingPaymentReceivedState` property to `ReportingPaymentReceivedState.error`, and updates its `Swap.state` property to `SwapState.awaitingPaymentReceived`.
     
     If `transaction` is of type `BlockchainTransactionType.closeSwap`, then this finds the swap with the corresponding close swap transaction hash, persistently updates its closing swap state to `ClosingSwapState.error` and its state to `SwapState.awaitingClosing`, and on the main `DispatchQueue` sets its `Swap.closingSwapError` to `error`, updates its `Swap.closingSwapState` property to `ClosingSwapState.error`, and updates its `Swap.state` property to `SwapState.awaitingClosing`.
     
     - Parameters:
        - transaction: The `BlockchainTransaction` wrapping the on-chain transaction that has failed.
        - error: A `BlockchainTransactionError` describing why the on-chain transaction has failed.
     
     - Throws: A `SwapServiceError.invalidValueError` if this is passed an offer-related `BlockchainTransaction`.
     */
    func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws {
        logger.warning("handleFailedTransaction: handling \(transaction.transactionHash) of type \(transaction.type.asString) with error \(error.localizedDescription)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleFailedTransactionCall for \(transaction.transactionHash)")
        }
        switch transaction.type {
        case .approveTokenTransferToOpenOffer, .openOffer, .cancelOffer, .editOffer, .approveTokenTransferToTakeOffer, .takeOffer:
            throw SwapServiceError.invalidValueError(desc: "handleFailedTransaction: received an offer-related transaction \(transaction.transactionHash)")
        case .approveTokenTransferToFillSwap:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.approvingToFillTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: swap with approve to fill transaction \(transaction.transactionHash) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID) with approve to fill transaction \(transaction.transactionHash), updating approvingToFillState to error in persistent storage")
            try databaseService.updateSwapApproveToFillState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: TokenTransferApprovalState.error.asString)
            logger.warning("handleFailedTransaction: setting approvingToFillError and updating approvingToFillState to error for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.approvingToFillError = error
                swap.approvingToFillState = .error
            }
        case .fillSwap:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.swapFillingTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: swap with swap filling transaction \(transaction.transactionHash) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID) with swap filling transaction \(transaction.transactionHash), updating state to \(SwapState.awaitingFilling.asString) and fillingSwapState to \(FillingSwapState.error.asString) in persistent storage")
            try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingFilling.asString)
            try databaseService.updateFillingSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: FillingSwapState.error.asString)
            logger.warning("handleFailedTransaction: setting state to \(SwapState.awaitingFilling.asString), setting fillingSwapError and updating fillingSwapState to \(FillingSwapState.error.asString) for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.state = SwapState.awaitingFilling
                swap.fillingSwapError = error
                swap.fillingSwapState = FillingSwapState.error
            }
        case .reportPaymentSent:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.reportPaymentSentTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: swap with report payment sent transaction \(transaction.transactionHash) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID) with report payment sent transaction \(transaction.transactionHash), updating reportingPaymentSentState to error and state to awaitingPaymentSent in persistent storage")
            try databaseService.updateReportPaymentSentState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentSentState.error.asString)
            try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingPaymentSent.asString)
            logger.warning("handleFailedTransaction: setting reportingPaymentSentError, updating reportingPaymentSentState to error and state to awaitingPaymentSent for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.reportingPaymentSentError = error
                swap.reportingPaymentSentState = .error
                swap.state = .awaitingPaymentSent
            }
        case .reportPaymentReceived:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.reportPaymentReceivedTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: swap with report payment received transaction \(transaction.transactionHash) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID) with report payment received transaction \(transaction.transactionHash), updating reportingPaymentReceivedState to error and state to awaitingPaymentReceived in persistent storage")
            try databaseService.updateReportPaymentReceivedState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ReportingPaymentReceivedState.error.asString)
            try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingPaymentReceived.asString)
            logger.warning("handleFailedTransaction: setting reportingPaymentReceivedError, updating reportingPaymentReceivedState to error and state to awaitingPaymentReceived for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.reportingPaymentReceivedError = error
                swap.reportingPaymentReceivedState = .error
                swap.state = .awaitingPaymentReceived
            }
        case .closeSwap:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.closeSwapTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: swap with close swap transaction \(transaction.transactionHash) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID) with close swap transaction \(transaction.transactionHash), updating closingSwapState to error and state to awaitingClosing in persistent storage")
            try databaseService.updateCloseSwapState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(swap.chainID), state: ClosingSwapState.error.asString)
            try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.awaitingClosing.asString)
            logger.warning("handleFailedTransaction: setting closingSwapError, updating closingSwapState to error and state to awaitingClosing for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.closingSwapError = error
                swap.closingSwapState = .error
                swap.state = .awaitingClosing
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
        let deserializedSelectedSettlementMethod = try? JSONDecoder().decode(SettlementMethod.self, from: swapOnChain.settlementMethod)
        if let deserializedSelectedSettlementMethod = deserializedSelectedSettlementMethod {
            let selectedSettlementMethod = takenOffer.settlementMethods.first { settlementMethod in
                return deserializedSelectedSettlementMethod.currency == settlementMethod.currency && deserializedSelectedSettlementMethod.price == settlementMethod.price && deserializedSelectedSettlementMethod.method == settlementMethod.method
            }
            if let selectedSettlementMethod = selectedSettlementMethod {
                newSwap.makerPrivateSettlementMethodData = selectedSettlementMethod.privateData
            } else {
                logger.warning("handleNewSwap: unable to find settlement for offer \(takenOffer.id) matching that selected by taker: \(swapOnChain.settlementMethod.base64EncodedString())")
            }
        } else {
            logger.warning("handleNewSwap: unable to deserialize selected settlement method \(swapOnChain.settlementMethod.base64EncodedString()) for \(takenOffer.id)")
        }
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
            role: newSwap.role.asString,
            approveToFillState: newSwap.approvingToFillState.asString,
            approveToFillTransactionHash: nil,
            approveToFillTransactionCreationTime: nil,
            approveToFillTransactionCreationBlockNumber: nil,
            fillingSwapState: newSwap.fillingSwapState.asString,
            fillingSwapTransactionHash: nil,
            fillingSwapTransactionCreationTime: nil,
            fillingSwapTransactionCreationBlockNumber: nil,
            reportPaymentSentState: newSwap.reportingPaymentSentState.asString,
            reportPaymentSentTransactionHash: nil,
            reportPaymentSentTransactionCreationTime: nil,
            reportPaymentSentTransactionCreationBlockNumber: nil,
            reportPaymentReceivedState: newSwap.reportingPaymentReceivedState.asString,
            reportPaymentReceivedTransactionHash: nil,
            reportPaymentReceivedTransactionCreationTime: nil,
            reportPaymentReceivedTransactionCreationBlockNumber: nil,
            closeSwapState: newSwap.closingSwapState.asString,
            closeSwapTransactionHash: nil,
            closeSwapTransactionCreationTime: nil,
            closeSwapTransactionCreationBlockNumber: nil
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
     The function called by `BlockchainService` to notify `SwapService` of an `ApprovalEvent`.
     
     If the purpose of `ApprovalEvent` is `TokenTransferApprovalPurpose.fillSwap`, this gets the swap with the corresponding approving to fill transaction hash, persistently updates its approving to fill state to `TokenTransferApprovalState.completed`, and then on the main `DispatchQueue` sets its `Swap.approvingToFillState` to `TokenTransferApprovalState.completed`.
     
     - Parameter event: The `ApprovalEvent` of which `SwapService` is being notified.
     
     - Throws: `SwapServiceError.unexpectedNilError` if `swapTruthSource` is `nil`, or a `SwapServiceError.invalidValueError` if `event` has an offer-related purpose.
     */
    func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) throws {
        logger.notice("handleTokenTransferApprovalEvent: handling event with tx hash \(event.transactionHash) and purpose \(event.purpose.asString)")
        guard let swapTruthSource = swapTruthSource else {
            throw SwapServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleTokenTransferApprovalEvent call for event with tx id \(event.transactionHash)")
        }
        switch event.purpose {
        case .openOffer, .takeOffer:
            throw SwapServiceError.invalidValueError(desc: "handleTokenTransferApprovalEvent: received a offer-related event of purpose \(event.purpose.asString) with tx hash \(event.transactionHash)")
        case .fillSwap:
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.approvingToFillTransaction?.transactionHash == event.transactionHash
            })?.value else {
                logger.warning("handleTokenTransferApprovalEvent: swap with approving to fill transaction \(event.transactionHash) not found in swapTruthSource")
                return
            }
            logger.notice("handleTokenTransferApprovalEvent: found swap \(swap.id.uuidString) with approvingToFill tx hash \(event.transactionHash), persistently updating approvingToFillState to \(TokenTransferApprovalState.completed.asString)")
            try databaseService.updateSwapApproveToFillState(swapID: swap.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: TokenTransferApprovalState.completed.asString)
            logger.notice("handleTokenTransferApprovalEvent: updating approvingToFillState to \(TokenTransferApprovalState.completed.asString) for \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.approvingToFillState = .completed
            }
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `SwapService` of a `SwapFilledEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a `Swap`, it ensures that the chain ID of the `Swap` and the chain ID of `event` match. Then it checks whether the swap is a maker-as-seller swap, and then whether the user is the maker and seller in the `Swap`. If both of these conditions are met, then this checks if the swap has a non-`nil` transaction for calling [fillSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#fill-swap). If it does, then this compares the hash of that transaction and the transaction hash contained in `event` If the two do not match, this sets a flag indicating that the swap filling transaction must be updated. If the swap does not have such a transaction, this flag is also set. If the user is not the maker and seller (and thus must be the buyer and taker, since this function will have already returned in other cases) in the `Swap`, this flag is also set. If this flag is set, then this updates the `Swap`, both in `swapTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether this flag is set, this persistently sets the `Swap.requiresFill` property of the `Swap` to `false`, persistently updates the `Swap.state` property of the `Swap` to `SwapState.awaitingPaymentSent`, and then, on the main `DispatchQueue`, sets the `Swap.requiresFill` property of the `Swap` to `false` and sets the `Swap.state` property of the `Swap` to `SwapState.awaitingPaymentSent`. Then, no longer on the main `DispatchQueue`, if the user is the maker and seller in this `Swap`, this updates the `Swap.fillingSwapState` of the `Swap` to `FillingSwapState.completed`, both in persistent storage and in the `Swap` itself.
     
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
                return
            case .makerAndSeller, .takerAndBuyer:
                logger.notice("handleSwapFilledEvent: handing for \(event.id.uuidString) as \(swap.role.asString)")
                var mustUpdateSwapFilledTransaction = false
                if swap.role == .makerAndSeller {
                    if let swapFillingTransaction = swap.swapFillingTransaction {
                        if swapFillingTransaction.transactionHash == event.transactionHash {
                            logger.notice("handleSwapFilledEvent: tx hash \(event.transactionHash) of event matches that for swap \(swap.id.uuidString): \(swapFillingTransaction.transactionHash)")
                        } else {
                            logger.warning("handleSwapFilledEvent: tx hash \(event.transactionHash) of event does not match that for swap \(event.id.uuidString): \(swapFillingTransaction.transactionHash), updating with new transaction hash")
                            mustUpdateSwapFilledTransaction = true
                        }
                    } else {
                        logger.warning("handleSwapFilledEvent: swap \(event.id.uuidString) for which user is maker and seller has no swap filling transaction, updating with transaction hash \(event.transactionHash)")
                        mustUpdateSwapFilledTransaction = true
                    }
                } else {
                    logger.info("handleSwapFilledEvent: user is taker and buyer for \(event.id.uuidString), updating with transaction hash \(event.transactionHash)")
                    mustUpdateSwapFilledTransaction = true
                }
                if mustUpdateSwapFilledTransaction {
                    let swapFillingTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .fillSwap)
                    DispatchQueue.main.sync {
                        swap.swapFillingTransaction = swapFillingTransaction
                    }
                    logger.info("handleSwapFilledEvent: persistently storing tx data, including hash \(event.transactionHash) for \(event.id.uuidString)")
                    let dateString = DateFormatter.createDateString(swapFillingTransaction.timeOfCreation)
                    try  databaseService.updateFillingSwapData(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), transactionHash: swapFillingTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(swapFillingTransaction.latestBlockNumberAtCreation))
                }
                logger.notice("handleSwapFilledEvent: persistently setting requiresFill property of \(event.id.uuidString) to false")
                try databaseService.updateSwapRequiresFill(swapID: swap.id.asData().base64EncodedString(), chainID: String(event.chainID), requiresFill: false)
                logger.notice("handleSwapFilledEvent: persistently updating state of \(event.id.uuidString) to \(SwapState.awaitingPaymentSent.asString)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(event.chainID), state: SwapState.awaitingPaymentSent.asString)
                logger.notice("handleSwapFilledEvent: setting requiresFill property of \(event.id.uuidString) to false and setting state of \(SwapState.awaitingPaymentSent.asString)")
                DispatchQueue.main.async {
                    swap.requiresFill = false
                    swap.state = .awaitingPaymentSent
                }
                if swap.role == .makerAndSeller {
                    logger.notice("handleSwapFilledEvent: user is maker and seller for \(event.id.uuidString) so persistently updating fillingSwapState to \(FillingSwapState.completed.asString)")
                    try databaseService.updateFillingSwapState(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: FillingSwapState.completed.asString)
                    logger.notice("handleSwapFilledEvent: updating fillingSwapState to \(FillingSwapState.completed.asString)")
                    DispatchQueue.main.sync {
                        swap.fillingSwapState = .completed
                    }
                }
            }
        } else {
            logger.notice("handleSwapFilledEvent: \(event.id) not made or taken by user")
            return
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `PaymentSentEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a `Swap`, it ensures that the chain ID of the `Swap` and the chain ID of `event` match. Then it checks whether the user is the buyer in the `Swap`. If the user is, then this checks if the swap has a non-`nil` transaction for calling [reportPaymentSent](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-sent). If it does, then this compares the hash of that transaction and the transaction hash contained in `event` If the two do not match, this sets a flag indicating that the reporting payment sent transaction must be updated. If the swap does not have such a transaction, this flag is also set. If the user is not the buyer in the `Swap`, this flag is also set. If this flag is set, then this updates the `Swap`, both in `swapTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether this flag is set, this persistently sets the `Swap.isPaymentSent` property of the `Swap` to `true`, persistently updates the `Swap.state` property of the `Swap` to `SwapState.awaitingPaymentReceived`, and then, on the main `DispatchQueue`, sets the `Swap.isPaymentSent` property of the `Swap` to `true` and sets the `Swap.state` property of the `Swap` to `SwapState.awaitingPaymentReceived`. Then, no longer on the main `DispatchQueue`, if the user is the buyer in this `Swap`, this updates the `Swap.reportingPaymentSentState` of the `Swap` to `ReportingPaymentSentState.completed`, both in persistent storage and in the `Swap` itself.
     
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
            var mustUpdateReportPaymentSentTransaction = false
            if swap.role == .makerAndBuyer || swap.role == .takerAndBuyer {
                logger.notice("handlePaymentSentEvent: user is buyer for \(event.id.uuidString)")
                if let reportPaymentSentTransaction = swap.reportPaymentSentTransaction {
                    if reportPaymentSentTransaction.transactionHash == event.transactionHash {
                        logger.notice("handlePaymentSentEvent: tx hash \(event.transactionHash) of event matches that for swap \(swap.id.uuidString): \(reportPaymentSentTransaction.transactionHash)")
                    } else {
                        logger.warning("handlePaymentSentEvent: tx hash \(event.transactionHash) of event does not match that for swap \(event.id.uuidString): \(reportPaymentSentTransaction.transactionHash), updating with new transaction hash")
                        mustUpdateReportPaymentSentTransaction = true
                    }
                } else {
                    logger.warning("handlePaymentSentEvent: swap \(event.id.uuidString) for which user is buyer has no reporting payment sent transaction, updating with transaction hash \(event.transactionHash)")
                    mustUpdateReportPaymentSentTransaction = true
                }
            } else {
                logger.info("handlePaymentSentEvent: user is seller for \(event.id.uuidString), updating with transaction hash \(event.transactionHash)")
                mustUpdateReportPaymentSentTransaction = true
            }
            if mustUpdateReportPaymentSentTransaction {
                let reportPaymentSentTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentSent)
                DispatchQueue.main.sync {
                    swap.reportPaymentSentTransaction = reportPaymentSentTransaction
                }
                logger.info("handlePaymentSentEvent: persistently storing tx data, including hash \(event.transactionHash) for \(event.id.uuidString)")
                let dateString = DateFormatter.createDateString(reportPaymentSentTransaction.timeOfCreation)
                try databaseService.updateReportPaymentSentData(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), transactionHash: reportPaymentSentTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(reportPaymentSentTransaction.latestBlockNumberAtCreation))
            }
            logger.notice("handlePaymentSentEvent: persistently setting isPaymentSent property of \(event.id.uuidString) to true")
            try databaseService.updateSwapIsPaymentSent(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), isPaymentSent: true)
            logger.notice("handlePaymentSentEvent: persistently updating state of \(event.id.uuidString) to \(SwapState.awaitingPaymentReceived.asString)")
            try databaseService.updateSwapState(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), state: SwapState.awaitingPaymentReceived.asString)
            logger.notice("handlePaymentSentEvent: setting isPaymentSent property of \(event.id.uuidString) to true and setting state to \(SwapState.awaitingPaymentReceived.asString)")
            DispatchQueue.main.sync {
                swap.isPaymentSent = true
                swap.state = .awaitingPaymentReceived
            }
            if swap.role == .makerAndBuyer || swap.role == .takerAndBuyer {
                logger.notice("handlePaymentSentEvent: user is buyer for \(event.id.uuidString) so persistently updating reportingPaymentSentState to \(ReportingPaymentSentState.completed.asString)")
                try databaseService.updateReportPaymentSentState(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: ReportingPaymentSentState.completed.asString)
                logger.notice("handlePaymentSentEvent: updating reportingPaymentSentState to \(ReportingPaymentSentState.completed.asString)")
                DispatchQueue.main.sync {
                    swap.reportingPaymentSentState = .completed
                }
            }
        } else {
            logger.notice("handlePaymentSentEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `PaymentReceivedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a `Swap`, it ensures that the chain ID of the `Swap` and the chain ID of `event` match. Then it checks whether the user is the seller in the `Swap`. If the user is, then this checks if the swap has a non-`nil` transaction for calling [reportPaymentReceived](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#report-payment-received). If it does, then this compares the hash of that transaction and the transaction hash contained in `event` If the two do not match, this sets a flag indicating that the reporting payment received transaction must be updated. If the swap does not have such a transaction, this flag is also set. If the user is not the buyer in the `Swap`, this flag is also set. If this flag is set, then this updates the `Swap`, both in `swapTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether this flag is set, this persistently sets the `Swap.isPaymentReceived` property of the `Swap` to `true`, persistently updates the `Swap.state` property of the `Swap` to `SwapState.awaitingClosing`, and then, on the main `DispatchQueue`, sets the `Swap.isPaymentSent` property of the `Swap` to `true` and sets the `Swap.state` property of the `Swap` to `SwapState.awaitingClosing`. Then, no longer on the main `DispatchQueue`, if the user is the buyer in this `Swap`, this updates the `Swap.reportingPaymentReceivedState` of the `Swap` to `ReportingPaymentReceivedState.completed`, both in persistent storage and in the `Swap` itself.
     
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
            var mustUpdateReportPaymentReceivedTransaction = false
            if swap.role == .makerAndSeller || swap.role == .takerAndSeller {
                logger.notice("handlePaymentReceivedEvent: user is buyer for \(event.id.uuidString)")
                if let reportPaymentReceivedTransaction = swap.reportPaymentReceivedTransaction {
                    if reportPaymentReceivedTransaction.transactionHash == event.transactionHash {
                        logger.notice("handlePaymentReceivedEvent: tx hash \(event.transactionHash) of event matches that for swap \(swap.id.uuidString): \(reportPaymentReceivedTransaction.transactionHash)")
                    } else {
                        logger.warning("handlePaymentReceivedEvent: tx hash \(event.transactionHash) of event does not match that for swap \(event.id.uuidString): \(reportPaymentReceivedTransaction.transactionHash), updating with new transaction hash")
                        mustUpdateReportPaymentReceivedTransaction = true
                    }
                } else {
                    logger.warning("handlePaymentReceivedEvent: swap \(event.id.uuidString) for which user is buyer has no reporting payment received transaction, updating with transaction hash \(event.transactionHash)")
                    mustUpdateReportPaymentReceivedTransaction = true
                }
            } else {
                logger.info("handlePaymentReceivedEvent: user is buyer for \(event.id.uuidString), updating with transaction hash \(event.transactionHash)")
                mustUpdateReportPaymentReceivedTransaction = true
            }
            if mustUpdateReportPaymentReceivedTransaction {
                let reportPaymentReceivedTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .reportPaymentReceived)
                DispatchQueue.main.sync {
                    swap.reportPaymentReceivedTransaction = reportPaymentReceivedTransaction
                }
                logger.info("handlePaymentReceivedEvent: persistently storing tx data, including hash \(event.transactionHash) for \(event.id.uuidString)")
                let dateString = DateFormatter.createDateString(reportPaymentReceivedTransaction.timeOfCreation)
                try databaseService.updateReportPaymentReceivedData(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), transactionHash: reportPaymentReceivedTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(reportPaymentReceivedTransaction.latestBlockNumberAtCreation))
            }
            logger.notice("handlePaymentReceivedEvent: persistently setting isPaymentReceived property of \(event.id.uuidString) to true")
            try databaseService.updateSwapIsPaymentReceived(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), isPaymentReceived: true)
            logger.notice("handlePaymentReceivedEvent: persistently updating state of \(event.id.uuidString) to \(SwapState.awaitingClosing.asString)")
            try databaseService.updateSwapState(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), state: SwapState.awaitingClosing.asString)
            logger.notice("handlePaymentReceivedEvent: setting isPaymentReceived property of \(event.id.uuidString) to true and setting state to \(SwapState.awaitingClosing.asString)")
            DispatchQueue.main.sync {
                swap.isPaymentReceived = true
                swap.state = .awaitingClosing
            }
            if swap.role == .makerAndSeller || swap.role == .takerAndSeller {
                logger.notice("handlePaymentReceivedEvent: user is seller for \(event.id.uuidString) so persistently updating reportingPaymentReceivedState to \(ReportingPaymentReceivedState.completed.asString)")
                try databaseService.updateReportPaymentReceivedState(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: ReportingPaymentReceivedState.completed.asString)
                logger.notice("handlePaymentReceivedEvent: updating reportingPaymentReceivedState to \(ReportingPaymentReceivedState.completed.asString)")
                DispatchQueue.main.sync {
                    swap.reportingPaymentReceivedState = .completed
                }
            }
        } else {
            logger.notice("handlePaymentReceivedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `BuyerClosedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a `Swap`, it ensures that the chain ID of the `Swap` and the chain ID of `event` match. Then it checks whether the user is the buyer in the `Swap`. If the user is, then this checks if the swap has a non-`nil` transaction for calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap). If it does, then this compares the hash of that transaction and the transaction hash contained in `event` If the two do not match, this sets a flag indicating that the swap closing transaction must be updated. If the swap does not have such a transaction, this flag is also set. If this flag is set, then this updates the `Swap`, both in `swapTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether this flag is set, this persistently updates the `Swap.state` property of the `Swap` to `SwapState.closed`, on the main `DispatchQueue` sets the `Swap.state` property of the `Swap` to `SwapState.closed`, persistently updates the `Swap.closingSwapState` of the `Swap` to `ClosingSwapState.completed`, on the main `DispatchQueue` sets the `Swap.closingSwapState` property of the `Swap` to `ClosingSwapState.completed`. Then, regardless of whether the user of this interface is the buyer or seller, this persistently updates the `Swap.hasBuyerClosed` property of the `Swap` to `true`, and then on the main `DispatchQueue` sets the `Swap.hasBuyerClosed` property to `true`.
     
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
            if swap.role == .makerAndBuyer || swap.role == .takerAndBuyer {
                logger.notice("handleBuyerClosedEvent: user is buyer for \(event.id.uuidString)")
                var mustUpdateCloseSwapTransaction = false
                if let closeSwapTransaction = swap.closeSwapTransaction {
                    if closeSwapTransaction.transactionHash == event.transactionHash {
                        logger.notice("handleBuyerClosedEvent: tx hash \(event.transactionHash) of event matches that for swap \(swap.id.uuidString): \(closeSwapTransaction.transactionHash)")
                    } else {
                        logger.warning("handleBuyerClosedEvent: tx hash \(event.transactionHash) of event does not match that for swap \(event.id.uuidString): \(closeSwapTransaction.transactionHash)")
                        mustUpdateCloseSwapTransaction = true
                    }
                } else {
                    logger.warning("handleBuyerClosedEvent: swap \(event.id.uuidString) for which user is buyer has no closing swap transaction, updating with transaction hash \(event.transactionHash)")
                    mustUpdateCloseSwapTransaction = true
                }
                if mustUpdateCloseSwapTransaction {
                    let closeSwapTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .closeSwap)
                    DispatchQueue.main.sync {
                        swap.closeSwapTransaction = closeSwapTransaction
                    }
                    logger.info("handleBuyerClosedEvent: persistently storing tx data, including hash \(event.transactionHash) for \(event.id.uuidString)")
                    let dateString = DateFormatter.createDateString(closeSwapTransaction.timeOfCreation)
                    try databaseService.updateCloseSwapData(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), transactionHash: closeSwapTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(closeSwapTransaction.latestBlockNumberAtCreation))
                }
                logger.notice("handleBuyerClosedEvent: persistently updating state of \(event.id.uuidString) to \(SwapState.closed.asString)")
                try databaseService.updateSwapState(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), state: SwapState.closed.asString)
                logger.notice("handleBuyerClosedEvent: setting state of \(event.id.uuidString) to \(SwapState.closed.asString)")
                DispatchQueue.main.sync {
                    swap.state = .closed
                }
                logger.notice("handleBuyerClosedEvent: user is buyer for \(event.id.uuidString) so persistently updating closingSwapState to \(ClosingSwapState.completed.asString)")
                try databaseService.updateCloseSwapState(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: ClosingSwapState.completed.asString)
                logger.notice("handleBuyerClosedEvent: updating closingSwapState to \(ClosingSwapState.completed.asString)")
                DispatchQueue.main.sync {
                    swap.closingSwapState = .completed
                }
            } else {
                logger.info("handleBuyerClosedEvent: user is seller for \(event.id.uuidString)")
            }
            logger.notice("handleBuyerClosedEvent: persistently setting hasBuyerClosed property of \(event.id.uuidString) to true")
            try databaseService.updateSwapHasBuyerClosed(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), hasBuyerClosed: true)
            logger.notice("handleBuyerClosedEvent: setting hasBuyerClosed property of \(event.id.uuidString) to true")
            DispatchQueue.main.sync {
                swap.hasBuyerClosed = true
            }
        } else {
            logger.notice("handleBuyerClosedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
    /**
     The function called by  `BlockchainService` to notify `SwapService` of a `SellerClosedEvent`.
     
     Once notified, `SwapService` checks in `swapTruthSource` for a `Swap` with the ID specified in `event`. If it finds such a `Swap`, it ensures that the chain ID of the `Swap` and the chain ID of `event` match. Then it checks whether the user is the seller in the `Swap`. If the user is, then this checks if the swap has a non-`nil` transaction for calling [closeSwap](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#close-swap). If it does, then this compares the hash of that transaction and the transaction hash contained in `event` If the two do not match, this sets a flag indicating that the swap closing transaction must be updated. If the swap does not have such a transaction, this flag is also set. If this flag is set, then this updates the `Swap`, both in `swapTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether this flag is set, this persistently updates the `Swap.state` property of the `Swap` to `SwapState.closed`, on the main `DispatchQueue` sets the `Swap.state` property of the `Swap` to `SwapState.closed`, persistently updates the `Swap.closingSwapState` of the `Swap` to `ClosingSwapState.completed`, on the main `DispatchQueue` sets the `Swap.closingSwapState` property of the `Swap` to `ClosingSwapState.completed`. Then, regardless of whether the user of this interface is the buyer or seller, this persistently updates the `Swap.hasSellerClosed` property of the `Swap` to `true`, and then on the main `DispatchQueue` sets the `Swap.hasSellerClosed` property to `true`.
     
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
            if swap.role == .makerAndSeller || swap.role == .takerAndSeller {
                logger.notice("handleSellerClosedEvent: user is seller for \(event.id.uuidString)")
                var mustUpdateCloseSwapTransaction = false
                if let closeSwapTransaction = swap.closeSwapTransaction {
                    if closeSwapTransaction.transactionHash == event.transactionHash {
                        logger.notice("handleSellerClosedEvent: tx hash \(event.transactionHash) of event matches that for swap \(swap.id.uuidString): \(closeSwapTransaction.transactionHash)")
                    } else {
                        logger.warning("handleSellerClosedEvent: tx hash \(event.transactionHash) of event does not match that for swap \(event.id.uuidString): \(closeSwapTransaction.transactionHash)")
                        mustUpdateCloseSwapTransaction = true
                    }
                } else {
                    logger.warning("handleSellerClosedEvent: swap \(event.id.uuidString) for which user is seller has no closing swap transaction, updating with transaction hash \(event.transactionHash)")
                    mustUpdateCloseSwapTransaction = true
                }
                if mustUpdateCloseSwapTransaction {
                    let closeSwapTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .closeSwap)
                    DispatchQueue.main.sync {
                        swap.closeSwapTransaction = closeSwapTransaction
                    }
                    logger.info("handleSellerClosedEvent: persistently storing tx data, including hash \(event.transactionHash) for \(event.id.uuidString)")
                    let dateString = DateFormatter.createDateString(closeSwapTransaction.timeOfCreation)
                    try databaseService.updateCloseSwapData(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), transactionHash: closeSwapTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(closeSwapTransaction.latestBlockNumberAtCreation))
                }
                logger.notice("handleSellerClosedEvent: persistently updating state of \(event.id.uuidString) to \(SwapState.closed.asString)")
                try databaseService.updateSwapState(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), state: SwapState.closed.asString)
                logger.notice("handleSellerClosedEvent: setting state of \(event.id.uuidString) to \(SwapState.closed.asString)")
                DispatchQueue.main.sync {
                    swap.state = .closed
                }
                logger.notice("handleSellerClosedEvent: user is seller for \(event.id.uuidString) so persistently updating closingSwapState to \(ClosingSwapState.completed.asString)")
                try databaseService.updateCloseSwapState(swapID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: ClosingSwapState.completed.asString)
                logger.notice("handleSellerClosedEvent: updating closingSwapState to \(ClosingSwapState.completed.asString)")
                DispatchQueue.main.sync {
                    swap.closingSwapState = .completed
                }
            } else {
                logger.info("handleSellerClosedEvent: user is buyer for \(event.id.uuidString)")
            }
            logger.notice("handleSellerClosedEvent: persistently setting hasSellerClosed property of \(event.id.uuidString) to true")
            try databaseService.updateSwapHasSellerClosed(swapID: event.id.asData().base64EncodedString(), chainID: String(event.chainID), hasSellerClosed: true)
            logger.notice("handleSellerClosedEvent: setting hasSellerClosed property of \(event.id.uuidString) to true")
            DispatchQueue.main.sync {
                swap.hasSellerClosed = true
            }
        } else {
            logger.notice("handleSellerClosedEvent: got event for \(event.id.uuidString) which was not found in swapTruthSource")
        }
    }
    
}

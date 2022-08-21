//
//  OfferService.swift
//  iosApp
//
//  Created by jimmyt on 6/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import BigInt
import Foundation
import os
import PromiseKit
import web3swift

/**
 The main Offer Service. It is responsible for processing and organizing offer-related data that it receives from `BlockchainService` and `P2PService` in order to maintain an accurate list of all open offers in `OffersViewModel`.
 */
class OfferService<_OfferTruthSource, _SwapTruthSource>: OfferNotifiable, OfferMessageNotifiable where _OfferTruthSource: OfferTruthSource, _SwapTruthSource: SwapTruthSource {
    
    /**
     Initializes a new OfferService object.
     
     - Parameters:
        - databaseService: The `DatabaseService` that the `OfferService` will use for persistent storage.
        - keyManagerService: The `KeyManagerService` that the `OfferService`will use for managing keys.
        - offerOpenedEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferOpenedEvent`s during `handleOfferOpenedEvent` calls.
        - offerEditedEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferEditedEvent`s during `handleOfferEditedEvent` calls.
        - offerCanceledEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferCanceledEvent`s during `handleOfferCanceledEvent` calls.
        - offerTakenEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferTakenEvent`s during `handleOfferTakenEvent` calls.
     */
    init(
        databaseService: DatabaseService,
        keyManagerService: KeyManagerService,
        offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent> = BlockchainEventRepository<OfferOpenedEvent>(),
        offerEditedEventRepository: BlockchainEventRepository<OfferEditedEvent> = BlockchainEventRepository<OfferEditedEvent>(),
        offerCanceledEventRepository: BlockchainEventRepository<OfferCanceledEvent> = BlockchainEventRepository<OfferCanceledEvent>(),
        offerTakenEventRepository: BlockchainEventRepository<OfferTakenEvent> = BlockchainEventRepository<OfferTakenEvent>()
    ) {
        self.databaseService = databaseService
        self.keyManagerService = keyManagerService
        self.offerOpenedEventRepository = offerOpenedEventRepository
        self.offerEditedEventRepository = offerEditedEventRepository
        self.offerCanceledEventRepository = offerCanceledEventRepository
        self.offerTakenEventRepository = offerTakenEventRepository
    }
    
    /**
     OfferService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "OfferService")
    
    /**
     An object adopting `OfferTruthSource` in which this is responsible for maintaining an accurate list of all open offers.
     */
    var offerTruthSource: _OfferTruthSource? = nil
    
    /**
     An object adopting `SwapTruthSource` in which this creates new `Swap`s as necessary.
     */
    var swapTruthSource: _SwapTruthSource? = nil
    
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
     A repository containing `OfferOpenedEvent`s for offers that are open and for which complete offer information has not yet been retrieved.
     */
    private var offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent>
    
    /**
     A repository containing `OfferEditedEvent`s for offers that are open and for which stored price and payment method information is currently inaccurate.
     */
    private var offerEditedEventRepository: BlockchainEventRepository<OfferEditedEvent>
    
    /**
     A repository containing `OfferCanceledEvent`s for offers that have been canceled but haven't yet been removed from persistent storage or `offerTruthSource`.
     */
    private var offerCanceledEventRepository: BlockchainEventRepository<OfferCanceledEvent>
    
    /**
     A repository containing `OfferTakenEvent`s for offers that have been taken but haven't yet been removed from persistent storage or `offerTruthSource`.
     */
    private var offerTakenEventRepository: BlockchainEventRepository<OfferTakenEvent>
    
    /**
     Returns the result of calling `blockchainService.getServiceFeeRate`, or throws an `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`.
     
     - Returns: The result of calling `blockchainService.getServiceFeeRate`
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise` these errors aren't thrown, but instead a rejected `Promise` is returned..
     */
    func getServiceFeeRate() -> Promise<BigUInt> {
        if blockchainService != nil {
            return blockchainService!.getServiceFeeRate()
        } else {
            return Promise(error: OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during getServiceFeeRate call"))
        }
    }
    
    /**
     Attempts to open a new [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer), using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this creates and persistently stores a new key pair, creates a new offer ID and a new `Offer` from the information contained in `offerData`. Then, still on the global `DispatchQueue`, this persistently stores the new `Offer`,  approves token transfer to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, calls the CommutoSwap contract's [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) function, passing the new offer ID and `Offer`, and updates the state of the offer to `openOfferTransactionBroadcast`. Then, on the main `DispatchQueue`, the new `Offer` is added to `offerTruthSource`.
     
     - Parameters:
        - offerData: A `ValidatedNewOfferData` containing the data for the new offer to be opened.
        - afterObjectCreation: A closure that will be executed after the new key pair, offer ID and `Offer` object are created.
        - afterPersistentStorage: A closure that will be executed after the `Offer` is persistently stored.
        - afterTransferApproval: A closure that will be executed after the token transfer approval to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
        - afterOpen: A closure that will be run after the offer is opened, via a call to [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer).
     
     - Returns: An empty promise that will be fulfilled when the new Offer is opened.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `offerTruthSource` is `nil` or if `blockchainService` is `nil`. Note that because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func openOffer(
        offerData: ValidatedNewOfferData,
        afterObjectCreation: (() -> Void)? = nil,
        afterPersistentStorage: (() -> Void)? = nil,
        afterTransferApproval: (() -> Void)? = nil,
        afterOpen: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Offer> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("openOffer: creating new ID, Offer object and creating and persistently storing new key pair for new offer")
                    do {
                        // Generate a new 2056 bit RSA key pair for the new offer
                        let newKeyPairForOffer = try keyManagerService.generateKeyPair(storeResult: true)
                        // Generate the a new ID for the offer
                        let newOfferID = UUID()
                        logger.notice("openOffer: created ID \(newOfferID.uuidString) for new offer")
                        // Create a new Offer
                        #warning("TODO: get proper chain ID here and maker address")
                        let newOffer = Offer(
                            isCreated: true,
                            isTaken: false,
                            id: newOfferID,
                            maker: EthereumAddress("0x0000000000000000000000000000000000000000")!, // It is safe to use the zero address here, because the maker address will be automatically set to that of the function caller by CommutoSwap
                            interfaceID: newKeyPairForOffer.interfaceId,
                            stablecoin: offerData.stablecoin,
                            amountLowerBound: offerData.minimumAmount,
                            amountUpperBound: offerData.maximumAmount,
                            securityDepositAmount: offerData.securityDepositAmount,
                            serviceFeeRate: offerData.serviceFeeRate,
                            direction: offerData.direction,
                            settlementMethods: offerData.settlementMethods,
                            protocolVersion: BigUInt.zero,
                            chainID: BigUInt(31337),
                            havePublicKey: true,
                            isUserMaker: true,
                            state: .opening
                        )
                        if let afterObjectCreation = afterObjectCreation {
                            afterObjectCreation()
                        }
                        seal.fulfill(newOffer)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] newOffer in
                logger.notice("openOffer: persistently storing \(newOffer.id.uuidString)")
                // Persistently store the new offer
                let newOfferForDatabase = DatabaseOffer(
                    id: newOffer.id.asData().base64EncodedString(),
                    isCreated: newOffer.isCreated,
                    isTaken: newOffer.isTaken,
                    maker: newOffer.maker.addressData.toHexString(),
                    interfaceId: newOffer.interfaceId.base64EncodedString(),
                    stablecoin: newOffer.stablecoin.addressData.toHexString(),
                    amountLowerBound: String(newOffer.amountLowerBound),
                    amountUpperBound: String(newOffer.amountUpperBound),
                    securityDepositAmount: String(newOffer.securityDepositAmount),
                    serviceFeeRate: String(newOffer.serviceFeeRate),
                    onChainDirection: String(newOffer.onChainDirection),
                    protocolVersion: String(newOffer.protocolVersion),
                    chainID: String(newOffer.chainID),
                    havePublicKey: newOffer.havePublicKey,
                    isUserMaker: newOffer.isUserMaker,
                    state: newOffer.state.asString
                )
                try databaseService.storeOffer(offer: newOfferForDatabase)
                if let afterPersistentStorage = afterPersistentStorage {
                    afterPersistentStorage()
                }
                var settlementMethodStrings: [String] = []
                for settlementMethod in newOffer.onChainSettlementMethods {
                    settlementMethodStrings.append(settlementMethod.base64EncodedString())
                }
                logger.notice("openOffer: persistently storing \(settlementMethodStrings.count) settlement methods for offer \(newOffer.id.uuidString)")
                try databaseService.storeSettlementMethods(offerID: newOfferForDatabase.id, _chainID: newOfferForDatabase.chainID, settlementMethods: settlementMethodStrings)
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] newOffer -> Promise<(Void, Offer)> in
                // Authorize token transfer to CommutoSwap contract
                let tokenAmountForOpeningOffer = newOffer.securityDepositAmount + newOffer.serviceFeeAmountUpperBound
                logger.notice("openOffer: authorizing transfer for \(newOffer.id.uuidString). Amount: \(String(tokenAmountForOpeningOffer))")
                guard blockchainService != nil else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during openOffer call")
                }
                // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
                return blockchainService!.approveTokenTransfer(tokenAddress: newOffer.stablecoin, destinationAddress: blockchainService!.commutoSwapAddress, amount: tokenAmountForOpeningOffer).map { ($0, newOffer) }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, newOffer -> Promise<(Void, Offer)> in
                if let afterTransferApproval = afterTransferApproval {
                    afterTransferApproval()
                }
                logger.notice("openOffer: opening \(newOffer.id.uuidString)")
                guard blockchainService != nil else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during openOffer call")
                }
                let newOfferStruct = newOffer.toOfferStruct()
                // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
                return blockchainService!.openOffer(offerID: newOffer.id, offerStruct: newOfferStruct).map { ($0, newOffer) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, newOffer in
                logger.notice("openOffer: opened \(newOffer.id.uuidString)")
                newOffer.state = .openOfferTransactionBroadcast
                try databaseService.updateOfferState(offerID: newOffer.id.asData().base64EncodedString(), _chainID: String(newOffer.chainID), state: newOffer.state.asString)
                logger.notice("openOffer: adding \(newOffer.id.uuidString) to offerTruthSource")
            }.get(on: DispatchQueue.main) { [self] _, newOffer in
                guard offerTruthSource != nil else {
                    throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during openOffer call")
                }
                offerTruthSource!.offers[newOffer.id] = newOffer
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _, newOffer in
                if let afterOpen = afterOpen {
                    afterOpen()
                }
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("openOffer: encountered error: \(error.localizedDescription)")
                seal.reject(error)
            }
            
        }
    }
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this persistently updates the state of the offer to `OfferState.canceling`, and then does the same to  the corresponding `Offer` in `offerTruthSource` on the main `DispatchQueue`. Then, back on the global `DispatchQueue`, this cancels the offer on chain by calling the CommutoSwap contract's [cancelOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#cancel-offer) function, passing the offer ID, and then persistently updates the state of the offer to `OfferState.cancelOfferTransactionBroadcast`.  Finally, on the main `DispatchQueue`, this sets the state of the `Offer` in `offerTruthSource` to `OfferState.cancelOfferTransactionBroadcast`.
     
     - Parameters:
        - offerID: The ID of the `Offer` to be canceled.
        - chainID: The ID of the blockchain on which the `Offer` exists.
     
     - Returns: An empty `Promise` that will be fulfilled when the Offer is canceled.
     
     - Throws: An `OfferServiceError.offerNotAvailableError` if the `isTaken` property of the `Offer` in in `offerTruthSource` to which `offerID` is mapped is true, or an `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func cancelOffer(offerID: UUID, chainID: BigUInt) -> Promise<Void> {
        return Promise { seal in
            Promise<Void> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("cancelOffer: canceling \(offerID.uuidString)")
                    // If we can't find the offer in offerTruthSource, we assume it is not taken
                    guard !(offerTruthSource?.offers[offerID]?.isTaken ?? false) else {
                        seal.reject(OfferServiceError.offerNotAvailableError(desc: "Offer \(offerID) is taken and cannot be canceled."))
                        return
                    }
                    do {
                        logger.notice("cancelOffer: persistently updating offer \(offerID.uuidString) state to canceling")
                        try databaseService.updateOfferState(offerID: offerID.asData().base64EncodedString(), _chainID: String(chainID), state: OfferState.canceling.asString)
                        logger.notice("cancelOffer: updating offer \(offerID.uuidString) state to canceling")
                        seal.fulfill(())
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { _ in
                self.offerTruthSource?.offers[offerID]?.state = .canceling
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ -> Promise<Void> in
                logger.notice("cancelOffer: canceling offer \(offerID.uuidString) on chain")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during cancelOffer call")
                }
                return blockchainService.cancelOffer(offerID: offerID)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("cancelOffer: persistently updating offer \(offerID.uuidString) state to cancelOfferTxBroadcast")
                do {
                    try databaseService.updateOfferState(offerID: offerID.asData().base64EncodedString(), _chainID: String(chainID), state: OfferState.cancelOfferTransactionBroadcast.asString)
                    logger.notice("cancelOffer: updating offer \(offerID.uuidString) state to cancelOfferTxBroadcast")
                }
            }.get(on: DispatchQueue.main) { _ in
                self.offerTruthSource?.offers[offerID]?.state = .cancelOfferTransactionBroadcast
            }.done(on: DispatchQueue.global(qos: .userInitiated)) {
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("cancelOffer: encountered error while canceling \(offerID.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this serializes the new settlement methods and calls the CommutoSwap contract's [editOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer) function, passing the offer ID and an `OfferStruct` containing the new serialized settlement methods.
     
     - Parameters:
        - offerID: The ID of the offer to edit.
        - newSettlementMethods: The new settlement methods with which the offer will be edited.
     
     - Returns: An empty `Promise` that will be fulfilled when the Offer is edited.
     
     - Throws: An `OfferServiceError.offerNotAvailableError` if the `isTaken` property of the `Offer` in `offerTruthSource` with an ID equal to `offerID` is true, or an `OfferServiceError.unexpectedNilError` if `offerTruthSource` is `nil`, if there is no `Offer`in `offerTruthSource` with an ID equal to `offerID`, or if `blockchainService` is `nil`. Note that because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func editOffer(offerID: UUID, newSettlementMethods: [SettlementMethod]) -> Promise<Void> {
        return Promise { seal in
            Promise<Array<Data>> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("editOffer: editing \(offerID.uuidString)")
                    guard let offerTruthSource = offerTruthSource else {
                        seal.reject(OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during editOffer call for \(offerID.uuidString)"))
                        return
                    }
                    guard let offer = offerTruthSource.offers[offerID] else {
                        seal.reject(OfferServiceError.unexpectedNilError(desc: "Offer \(offerID.uuidString) was not found."))
                        return
                    }
                    guard !offer.isTaken else {
                        seal.reject(OfferServiceError.offerNotAvailableError(desc: "Offer \(offerID.uuidString) is already taken."))
                        return
                    }
                    do {
                        logger.notice("editOffer: serializing settlement methods for \(offerID.uuidString)")
                        let onChainSettlementMethods = try newSettlementMethods.compactMap { settlementMethod in
                            return try JSONEncoder().encode(settlementMethod)
                        }
                        seal.fulfill(onChainSettlementMethods)
                    } catch {
                        self.logger.error("editOffer: encountered error serializing settlement methods for \(offerID.uuidString): \(error.localizedDescription)")
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] onChainSettlementMethods -> Promise<Void> in
                logger.notice("editOffer: editing \(offerID.uuidString) on chain")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during editOffer call")
                }
                /*
                 Since editOffer only uses the settlement methods of the passed Offer struct, we put meaningless values in all other properties of the passed struct.
                 */
                let offerStruct = OfferStruct(
                    isCreated: false,
                    isTaken: false,
                    maker: EthereumAddress("0x0000000000000000000000000000000000000000")!,
                    interfaceId: Data(),
                    stablecoin: EthereumAddress("0x0000000000000000000000000000000000000000")!,
                    amountLowerBound: BigUInt.zero,
                    amountUpperBound: BigUInt.zero,
                    securityDepositAmount: BigUInt.zero,
                    serviceFeeRate: BigUInt.zero,
                    direction: BigUInt.zero,
                    settlementMethods: onChainSettlementMethods,
                    protocolVersion: BigUInt.zero,
                    chainID: BigUInt.zero
                )
                return blockchainService.editOffer(
                    offerID: offerID,
                    offerStruct: offerStruct
                )
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                self.logger.notice("editOffer: successfully edited \(offerID.uuidString)")
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("editOffer: encountered error while canceling \(offerID.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer), using the process described in the [interface specification](https://github.com/jimmyneutront/commuto-whitepaper/blob/main/commuto-interface-specification.txt).
     
     On the global `DispatchQueue`, this ensures that an offer with an ID equal to that of `offerToTake` exists on chain and is not taken, creates and persistently stores a new `KeyPair` and a new `Swap` with the information contained in `offerToTake` and `swapData`. Then, still on the global `DispatchQueue`, this approves token transfer for the proper amount to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, calls the CommutoSwap contract's [takeOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#take-offer) function (via `BlockchainService`), passing the offer ID and new `Swap`, and then updates the state of `offerToTake` to `taken` and the state of the swap to `takeOfferTransactionBroadcast`. Then, on the main `DispatchQueue`, the new `Swap` is added to `swapTruthSource` and `offerToTake` is removed from `offerTruthSource`.
     
     - Parameters:
        - offerToTake: The `Offer` that this function will take.
        - swapData: A `ValidatedNewSwapData` containing data necessary for taking `offerToTake`.
        - afterAvailabilityCheck: A closure that will be executed after this has ensured that the offer exists and is not taken.
        - afterObjectCreation: A closure that will be executed after the new `KeyPair` and `Swap` objects are created.
        - afterPersistentStorage: A closure that will be executed after the `Swap` is persistently stored.
        - afterTransferApproval: A closure that will be executed after the token transfer approval to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
     
     - Returns: An empty promise that will be fulfilled when the Offer is taken.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService`, `swapTruthSource`, or `offerTruthSource` is `nil`, or if an offer with an ID equal to that of `offerToTake` does not exist on-chain, or an `OfferServiceError.offerNotAvailableError` if the offer is not created or is already taken. Note that because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func takeOffer(
        offerToTake: Offer,
        swapData: ValidatedNewSwapData,
        afterAvailabilityCheck: (() -> Void)? = nil,
        afterObjectCreation: (() -> Void)? = nil,
        afterPersistentStorage: (() -> Void)? = nil,
        afterTransferApproval: (() -> Void)? = nil
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<Swap> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("takeOffer: checking that \(offerToTake.id.uuidString) is created and not taken")
                    do {
                        // Try to get the on-chain offer corresponding to offerToTake
                        guard let blockchainService = blockchainService else {
                            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(offerToTake.id.uuidString)")
                        }
                        guard let offerOnChain = try blockchainService.getOffer(id: offerToTake.id) else {
                            throw OfferServiceError.unexpectedNilError(desc: "Unable to find on-chain offer with id \(offerToTake.id.uuidString)")
                        }
                        if !offerOnChain.isCreated {
                            throw OfferServiceError.offerNotAvailableError(desc: "Offer \(offerToTake.id.uuidString) does not exist")
                        }
                        if offerOnChain.isTaken {
                            throw OfferServiceError.offerNotAvailableError(desc: "Offer \(offerToTake.id.uuidString) has already been taken")
                        }
                        if let afterAvailabilityCheck = afterAvailabilityCheck {
                            afterAvailabilityCheck()
                        }
                        logger.notice("takeOffer: creating Swap object and creating and persistently storing new key pair to take offer \(offerToTake.id.uuidString)")
                        // Generate a new 2056 bit RSA key pair to take the swap
                        let newKeyPairForSwap = try keyManagerService.generateKeyPair(storeResult: true)
                        var requiresFill: Bool {
                            switch(offerToTake.direction) {
                            case .buy:
                                return false
                            case .sell:
                                return true
                            }
                        }
                        let serviceFeeAmount = (swapData.takenSwapAmount * offerToTake.serviceFeeRate) / BigUInt(10_000)
                        #warning("TODO: get proper taker address here")
                        /*
                         We can't simply use the SettlementMethod object in the swapData, because CommutoSwap doesn't allow us to take the offer unless the serialized settlement method data that we use in the takeOffer call exactly matches the serialized settlement method data supplied by the offer maker, and SettlementMethod objects aren't serialized the same way on every platform. Therefore we must find and use the serialized settlement method data supplied by the offer maker in offerToTake.
                         */
                        guard let selectedOnChainSettlementMethod = (offerToTake.onChainSettlementMethods.first { onChainSettlementMethod in
                            do {
                                let settlementMethod = try JSONDecoder().decode(SettlementMethod.self, from: onChainSettlementMethod)
                                if settlementMethod.currency == swapData.settlementMethod.currency && settlementMethod.price == swapData.settlementMethod.price && settlementMethod.method == swapData.settlementMethod.method {
                                    return true
                                } else {
                                    return false
                                }
                            } catch {
                                logger.warning("takeOffer: got exception while deserializing settlement method \(onChainSettlementMethod.base64EncodedString()) for \(offerToTake.id.uuidString): \(error.localizedDescription)")
                                return false
                            }
                        }) else {
                            throw OfferServiceError.unexpectedNilError(desc: "Unable to find specified settlement method in list of settlement methods accepted by offer maker")
                        }
                        let newSwap = try Swap(
                            isCreated: true,
                            requiresFill: requiresFill,
                            id: offerToTake.id,
                            maker: offerToTake.maker,
                            makerInterfaceID: offerToTake.interfaceId,
                            taker: EthereumAddress("0x0000000000000000000000000000000000000000")!, // It is safe to use the zero address here, because the maker address will be automatically set to that of the function caller by CommutoSwap,
                            takerInterfaceID: newKeyPairForSwap.interfaceId,
                            stablecoin: offerToTake.stablecoin,
                            amountLowerBound: offerToTake.amountLowerBound,
                            amountUpperBound: offerToTake.amountUpperBound,
                            securityDepositAmount: offerToTake.securityDepositAmount,
                            takenSwapAmount: swapData.takenSwapAmount,
                            serviceFeeAmount: serviceFeeAmount,
                            serviceFeeRate: offerToTake.serviceFeeRate,
                            direction: offerToTake.direction,
                            onChainSettlementMethod: selectedOnChainSettlementMethod,
                            protocolVersion: offerToTake.protocolVersion,
                            isPaymentSent: false,
                            isPaymentReceived: false,
                            hasBuyerClosed: false,
                            hasSellerClosed: false,
                            onChainDisputeRaiser: BigUInt.zero,
                            chainID: offerToTake.chainID,
                            state: .taking
                        )
                        if let afterObjectCreation = afterObjectCreation {
                            afterObjectCreation()
                        }
                        seal.fulfill(newSwap)
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] newSwap in
                logger.notice("takeOffer: persistently storing \(newSwap.id.uuidString)")
                // Persistently store the new swap
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
                if let afterPersistentStorage = afterPersistentStorage {
                    afterPersistentStorage()
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] newSwap -> Promise<(Void, Swap)> in
                var tokenAmountForTakingOffer: BigUInt {
                    switch (newSwap.direction) {
                    case .buy:
                        // We are taking a BUY offer, so we are SELLING stablecoin. Therefore we must authorize a transfer equal to the taken swap amount, the security deposit amount, and the service fee amount to the CommutoSwap contract.
                        return newSwap.takenSwapAmount + newSwap.securityDepositAmount + newSwap.serviceFeeAmount
                    case .sell:
                        // We are taking a SELL offer, so we are BUYING stablecoin. Therefore we must authorize a transfer equal to the security deposit amount and the service fee amount to the CommutoSwap contract.
                        return newSwap.securityDepositAmount + newSwap.serviceFeeAmount
                    }
                }
                logger.notice("takeOffer: authorizing transfer for \(newSwap.id.uuidString). Amount: \(String(tokenAmountForTakingOffer))")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(newSwap.id.uuidString)")
                }
                return blockchainService.approveTokenTransfer(tokenAddress: newSwap.stablecoin, destinationAddress: blockchainService.commutoSwapAddress, amount: tokenAmountForTakingOffer).map { ($0, newSwap) }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, newSwap -> Promise<(Void, Swap)> in
                if let afterTransferApproval = afterTransferApproval {
                    afterTransferApproval()
                }
                logger.notice("takeOffer: taking \(newSwap.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(newSwap.id.uuidString)")
                }
                return blockchainService.takeOffer(offerID: newSwap.id, swapStruct: newSwap.toSwapStruct()).map { ($0, newSwap) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, newSwap in
                logger.notice("takeOffer: took \(newSwap.id.uuidString)")
                offerToTake.state = .taken
                try databaseService.updateOfferState(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID), state: offerToTake.state.asString)
                newSwap.state = .takeOfferTransactionBroadcast
                try databaseService.updateSwapState(swapID: newSwap.id.asData().base64EncodedString(), chainID: String(newSwap.chainID), state: newSwap.state.asString)
                logger.notice("takeOffer: adding \(newSwap.id.uuidString) to swapTruthSource and removing \(offerToTake.id.uuidString) from offerTruthSource")
            }.get(on: DispatchQueue.main) { [self] _, newSwap in
                guard var swapTruthSource = swapTruthSource else {
                    throw OfferServiceError.unexpectedNilError(desc: "swapTruthSource was nil during takeOffer call for \(newSwap.id.uuidString)")
                }
                swapTruthSource.swaps[newSwap.id] = newSwap
                guard var offerTruthSource = offerTruthSource else {
                    throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                offerTruthSource.offers[offerToTake.id]?.isTaken = true
                offerTruthSource.offers.removeValue(forKey: offerToTake.id)
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, newSwap in
                logger.notice("takeOffer: removing offer \(offerToTake.id.uuidString) from persistent storage")
                try databaseService.deleteOffers(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID))
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("takeOffer: encountered error during call for \(offerToTake.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`.
     
     Once notified, `OfferService` saves `event` in `offerOpenedEventsRepository`, gets all on-chain offer data by calling `blockchainServices's` `getOffer` method, verifies that the chain ID of the event and the offer data match, and then checks if the offer has been persistently stored in `databaseService`. If it has been persistently stored and if its `isUserMaker` field is true, then the user of this interface has created this offer, and so `OfferService`updates the offer's state to `awaitingPublicKeyAnnouncement`, announces its corresponding public key by getting its key pair from `keyManagerService` and passing the key pair and the offer ID specified in `event` to `P2PService.announcePublicKey`, and then updates the offer state to `offerOpened`. If the offer has not been persistently stored or if its `isUserMaker` field is false, then `OfferService` creates a new `Offer` and list of settlement methods with the results, checks if `keyManagerService` has the maker's public key and updates the `Offer`'s `havePublicKey` and `state` properties accordingly, persistently stores the new offer and its settlement methods, removes `event` from `offerOpenedEventsRepository`, and then synchronously maps the offer's ID to the new `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferOpenedEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError` or `OfferServiceError.nonmatchingChainIDError`.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) throws {
        logger.notice("handleOfferOpenedEvent: handling event for offer \(event.id.uuidString)")
        offerOpenedEventRepository.append(event)
        guard blockchainService != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferOpenedEvent call")
        }
        // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
        guard let offerStruct = try blockchainService!.getOffer(id: event.id) else {
            logger.notice("handleOfferOpenedEvent: no on-chain offer was found with ID specified in OfferOpenedEvent in handleOfferOpenedEvent call. OfferOpenedEvent.id: \(event.id.uuidString)")
            return
        }
        logger.notice("handleOfferOpenedEvent: got offer \(event.id.uuidString)")
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferOpenedEvent did not match chain ID of OfferStruct in handleOfferOpenedEvent call. OfferOpenedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID) + ", OfferOpenedEvent.id: " + event.id.uuidString)
        }
        // Check if the offer is already in the database, and if it is, whether the user of this interface is the maker of the offer.
        let offerInDatabase = try databaseService.getOffer(id: event.id.asData().base64EncodedString())
        var isUserMaker = false
        if let offerInDatabase = offerInDatabase {
            isUserMaker = offerInDatabase.isUserMaker
        }
        if isUserMaker {
            logger.notice("handleOfferOpenedEvent: offer \(event.id.uuidString) made by the user")
            // The user of this interface is the maker of this offer, so we must announce the public key.
            guard let keyPair = try keyManagerService.getKeyPair(interfaceId: offerStruct.interfaceId) else {
                throw OfferServiceError.unexpectedNilError(desc: "handleOfferOpenedEvent: got nil while getting key pair with interface ID \(offerStruct.interfaceId.base64EncodedString()) for offer \(event.id.uuidString), which was made by the user")
            }
            guard let p2pService = p2pService else {
                throw OfferServiceError.unexpectedNilError(desc: "handleOfferOpenedEvent: p2pService was nil during handleOfferOpenedEvent call")
            }
            /*
             We do update the state of the persistently stored offer here but not the state of the corresponding Offer in offerTruthSource, since the offer should only remain in the awaitingPublicKeyAnnouncement state for a few moments.
             */
            try databaseService.updateOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OfferState.awaitingPublicKeyAnnouncement.asString)
            logger.notice("handleOfferOpenedEvent: announcing public key for \(event.id.uuidString)")
            try p2pService.announcePublicKey(offerID: event.id, keyPair: keyPair)
            logger.notice("handleOfferOpenedEvent: announced public key for \(event.id.uuidString)")
            try databaseService.updateOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OfferState.offerOpened.asString)
            guard let offerTruthSource = offerTruthSource else {
                throw OfferServiceError.unexpectedNilError(desc: "handleOfferOpenedEvent: offerTruthSource was nil during handleOfferOpenedEvent call")
            }
            guard offerTruthSource.offers[event.id] != nil else {
                logger.warning("handleOfferOpenedEvent: offer \(event.id.uuidString) (made by interface user) not found in offerTruthSource during handleOfferOpenedEvent call")
                offerOpenedEventRepository.remove(event)
                return
            }
            DispatchQueue.main.sync {
                offerTruthSource.offers[event.id]?.state = .offerOpened
                print(offerTruthSource.offers[event.id])
            }
            offerOpenedEventRepository.remove(event)
        } else {
            logger.notice("handleOfferOpenedEvent: offer \(event.id.uuidString) not made by the user")
            // The user of this interface is not the maker of this offer, so we treat it as a new offer.
            let havePublicKey = (try keyManagerService.getPublicKey(interfaceId: offerStruct.interfaceId) != nil)
            logger.notice("handleOfferOpenedEvent: havePublicKey for offer \(event.id.uuidString): \(havePublicKey)")
            var offerState: OfferState {
                if havePublicKey {
                    return .offerOpened
                } else {
                    return .awaitingPublicKeyAnnouncement
                }
            }
            guard let offer = Offer(
                isCreated: offerStruct.isCreated,
                isTaken: offerStruct.isTaken,
                id: event.id,
                maker: offerStruct.maker,
                interfaceId: event.interfaceId,
                stablecoin: offerStruct.stablecoin,
                amountLowerBound: offerStruct.amountLowerBound,
                amountUpperBound: offerStruct.amountUpperBound,
                securityDepositAmount: offerStruct.securityDepositAmount,
                serviceFeeRate: offerStruct.serviceFeeRate,
                onChainDirection: offerStruct.direction,
                onChainSettlementMethods: offerStruct.settlementMethods,
                protocolVersion: offerStruct.protocolVersion,
                chainID: offerStruct.chainID,
                havePublicKey: havePublicKey,
                isUserMaker: false,
                state: offerState
            ) else {
                throw OfferServiceError.unexpectedNilError(desc: "Got nil while creating Offer from OfferStruct data during handleOfferOpenedEvent call. OfferOpenedEvent.id: " + event.id.uuidString)
            }
            let offerForDatabase = DatabaseOffer(
                id: offer.id.asData().base64EncodedString(),
                isCreated: offer.isCreated,
                isTaken: offer.isTaken,
                maker: offer.maker.addressData.toHexString(),
                interfaceId: offer.interfaceId.base64EncodedString(),
                stablecoin: offer.stablecoin.addressData.toHexString(),
                amountLowerBound: String(offer.amountLowerBound),
                amountUpperBound: String(offer.amountUpperBound),
                securityDepositAmount: String(offer.securityDepositAmount),
                serviceFeeRate: String(offer.serviceFeeRate),
                onChainDirection: String(offer.onChainDirection),
                protocolVersion: String(offer.protocolVersion),
                chainID: String(offer.chainID),
                havePublicKey: offer.havePublicKey,
                isUserMaker: offer.isUserMaker,
                state: offer.state.asString
            )
            try databaseService.storeOffer(offer: offerForDatabase)
            logger.notice("handleOfferOpenedEvent: persistently stored offer \(offer.id.uuidString)")
            var settlementMethodStrings: [String] = []
            for settlementMethod in offer.onChainSettlementMethods {
                settlementMethodStrings.append(settlementMethod.base64EncodedString())
            }
            try databaseService.storeSettlementMethods(offerID: offerForDatabase.id, _chainID: offerForDatabase.chainID, settlementMethods: settlementMethodStrings)
            logger.notice("handleOfferOpenedEvent: persistently stored \(settlementMethodStrings.count) settlement methods for offer \(offer.id.uuidString)")
            offerOpenedEventRepository.remove(event)
            guard offerTruthSource != nil else {
                throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferOpenedEvent call")
            }
            // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
            DispatchQueue.main.sync {
                offerTruthSource!.offers[offer.id] = offer
            }
            logger.notice("handleOfferOpenedEvent: added offer \(offer.id.uuidString) to offerTruthSource")
        }
    }
    
    #warning("TODO: when we support multiple chains, someone could corrupt the interface's knowledge of settlement methods on Chain A by creating another offer with the same ID on Chain B and then changing the settlement methods of the offer on Chain B. If this interface is listening to both, it will detect the OfferEditedEvent from Chain B and then use the settlement methods from the offer on Chain B to update its local Offer object corresponding to the object from Chain A. We should only update settlement methods if the chainID of the OfferEditedEvent matches that of the already-stored offer")
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferEditedEvent`.
     
     Once notified, `OfferService` saves `event` in `offerEditedEventsRepository`, gets updated on-chain offer data by calling `blockchainService`'s `getOffer` method, verifies that the chain ID of the event and the offer data match, checks for the existence of an offer corresponding to the ID specified in `event` in persistent storage, updates the settlement methods of the corresponding persistently stored offer, removes `event` from `offerEditedEventsRepository`, and then synchronously updates the settlement methods of the offer with the ID specified in `event` (if present) in `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferEditedEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError` or `OfferServiceError.nonmatchingChainIDError`.
     */
    func handleOfferEditedEvent(_ event: OfferEditedEvent) throws {
        logger.notice("handleOfferEditedEvent: handling event for offer \(event.id.uuidString)")
        offerEditedEventRepository.append(event)
        guard blockchainService != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferEditedEvent call")
        }
        // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
        guard let offerStruct = try blockchainService!.getOffer(id: event.id) else {
            logger.notice("handleOfferEditedEvent: no on-chain offer was found with ID specified in OfferOpenedEvent in handleOfferOpenedEvent call. OfferOpenedEvent.id: \(event.id.uuidString)")
            return
        }
        logger.notice("handleOfferEditedEvent: got offer \(event.id.uuidString)")
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferEditedEvent did not match chain ID of OfferStruct in handleOfferEditedEvent call. OfferEditedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID))
        }
        logger.notice("handleOfferEditedEvent: checking for offer \(event.id.uuidString) in databaseService")
        let offerInDatabase = try databaseService.getOffer(id: event.id.asData().base64EncodedString())
        if offerInDatabase == nil {
            logger.warning("handleOfferEditedEvent: could not find persistently stored offer \(event.id.uuidString) during handleOfferEditedEvent call")
        }
        let offerIdString = event.id.asData().base64EncodedString()
        let chainIDString = String(event.chainID)
        var settlementMethodStrings: [String] = []
        for settlementMethod in offerStruct.settlementMethods {
            settlementMethodStrings.append(settlementMethod.base64EncodedString())
        }
        try databaseService.storeSettlementMethods(offerID: offerIdString, _chainID: chainIDString, settlementMethods: settlementMethodStrings)
        logger.notice("handleOfferEditedEvent: persistently stored \(settlementMethodStrings.count) settlement methods for offer \(event.id.uuidString)")
        guard let offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferEditedEvent call")
        }
        if let offer = offerTruthSource.offers[event.id] {
            DispatchQueue.main.async {
                offer.updateSettlementMethodsFromChain(onChainSettlementMethods: offerStruct.settlementMethods)
            }
            logger.notice("handleOfferEditedEvent: updated offer \(event.id.uuidString) in offerTruthSource")
        } else {
            logger.warning("handleOfferEditedEvent: could not find offer \(event.id.uuidString) in offerTruthSource")
        }
        offerEditedEventRepository.remove(event)
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferCanceledEvent`. Once notified, `OfferService` saves `event` in `offerCanceledEventsRepository`, removes the corresponding offer and its settlement methods from persistent storage, removes `event` from `offerCanceledEventsRepository`, and then checks that the chain ID of the event matches the chain ID of the `Offer` mapped to the offer ID specified in `event` in `offerTruthSource`;s `offers` dictionary on the main thread. If they do not match, this returns. If they do match, then this synchronously removes the `Offer` from said `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferCanceledEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) throws {
        logger.notice("handleOfferCanceledEvent: handling event for offer \(event.id.uuidString)")
        let offerIdString = event.id.asData().base64EncodedString()
        offerCanceledEventRepository.append(event)
        try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
        logger.notice("handleOfferCanceledEvent: deleted offer \(event.id.uuidString) from persistent storage")
        try databaseService.deleteSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
        logger.notice("handleOfferCanceledEvent: deleted settlement methods of offer \(event.id.uuidString) from persistent storage")
        offerCanceledEventRepository.remove(event)
        guard var offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferCanceledEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            if offerTruthSource.offers[event.id]?.chainID == event.chainID {
                offerTruthSource.offers[event.id]?.isCreated = false
                offerTruthSource.offers[event.id]?.state = .canceled
                offerTruthSource.offers.removeValue(forKey: event.id)
            }
        }
        logger.notice("handleOfferCanceledEvent: removed offer \(event.id.uuidString) from offerTruthSource if present")
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferTakenEvent`. Once notified, `OfferService` saves `event` in `offerTakenEventsRepository`, removes the corresponding offer and its settlement methods from persistent storage, removes `event` from `offerTakenEventsRepository`, and then checks that the chain ID of the event matches the chain ID of the `Offer` mapped to the offer ID specified in `event` in `offerTruthSource`'s `offers` dictionary on the main thread. If they do not match, this returns. If they do match, then this synchronously removes the `Offer` from said `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferTakenEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) throws {
        logger.notice("handleOfferTakenEvent: handling event for offer \(event.id.uuidString)")
        let offerIdString = event.id.asData().base64EncodedString()
        offerTakenEventRepository.append(event)
        try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
        logger.notice("handleOfferTakenEvent: deleted offer \(event.id.uuidString) from persistent storage")
        try databaseService.deleteSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
        logger.notice("handleOfferTakenEvent: deleted settlement methods of offer \(event.id.uuidString) from persistent storage")
        offerTakenEventRepository.remove(event)
        guard var offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferTakenEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            if offerTruthSource.offers[event.id]?.chainID == event.chainID {
                offerTruthSource.offers[event.id]?.isTaken = true
                offerTruthSource.offers.removeValue(forKey: event.id)
            }
        }
        logger.notice("handleOfferTakenEvent: removed offer \(event.id.uuidString) from offerTruthSource if present")
    }
    
    /**
     The function called by `P2PService` to notify `OfferService` of a `PublicKeyAnnouncement`.
     
     Once notified, `OfferService` checks that the public key in `message` is not already saved in persistent storage via `keyManagerService`, and does so if it is not. Then this checks `offerTruthSource` for an offer with the ID specified in `message` and an interface ID equal to that of the public key in `message`. If it finds such an offer, it checks the offer's `havePublicKey` and `state` properties. If `havePublicKey` is true or `state` is at or beyond `offerOpened`, then it returns because this interface already has the public key for this offer. Otherwise, it updates the offer's `havePublicKey` property to true, to indicate that we have the public key necessary to take the offer and communicate with its maker, and if the offer has not already passed through the `offerOpened` state, updates its `state` property to `offerOpened`. It updates these properties in persistent storage as well.
     
     - Parameter message: The `PublicKeyAnnouncement` of which `OfferService` is being notified.
     */
    func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) throws {
        logger.notice("handlePublicKeyAnnouncement: handling announcement for offer \(message.offerId.uuidString)")
        if try keyManagerService.getPublicKey(interfaceId: message.publicKey.interfaceId) == nil {
            try keyManagerService.storePublicKey(pubKey: message.publicKey)
            logger.notice("handlePublicKeyAnnouncement: persistently stored new public key with interface ID \(message.publicKey.interfaceId.base64EncodedString()) for offer \(message.offerId.uuidString)")
        } else {
            logger.notice("handlePublicKeyAnnouncement: already had public key in announcement in persistent storage. Interface ID: \(message.publicKey.interfaceId.base64EncodedString())")
        }
        guard let offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handlePublicKeyAnnouncement call")
        }
        guard let offer = DispatchQueue.main.sync(execute: {
            offerTruthSource.offers[message.offerId]
        }) else {
            logger.notice("handlePublicKeyAnnouncement: got announcement for offer not in offerTruthSource: \(message.offerId.uuidString)")
            return
        }
        /*
         If we already have the public key for an offer and/or that offer is at or beyond the offerOpened state (such as an offer made by this interface's user), then we do nothing.
         */
        guard offer.havePublicKey == false && offer.state.indexNumber < OfferState.offerOpened.indexNumber else {
            logger.notice("handlePublicKeyAnnouncement: got announcement for offer for which public key was already obtained: \(message.offerId.uuidString)")
            return
        }
        if offer.interfaceId == message.publicKey.interfaceId {
            DispatchQueue.main.sync {
                let offerInTruthSource = offerTruthSource.offers[message.offerId]
                offerInTruthSource?.havePublicKey = true
                let stateIndexNumber = offerTruthSource.offers[message.offerId]?.state.indexNumber
                if let stateIndexNumber = stateIndexNumber {
                    if stateIndexNumber < OfferState.offerOpened.indexNumber {
                        offerTruthSource.offers[message.offerId]?.state = OfferState.offerOpened
                    }
                }
            }
            logger.notice("handlePublicKeyAnnouncement: set havePublicKey true for offer \(message.offerId.uuidString)")
            let offerIDString = message.offerId.asData().base64EncodedString()
            let chainIDString = String(offer.chainID)
            if offer.state.indexNumber <= OfferState.offerOpened.indexNumber {
                try databaseService.updateOfferState(offerID: offerIDString, _chainID: chainIDString, state: OfferState.offerOpened.asString)
                logger.notice("handlePublicKeyAnnouncement: persistently set state as offerOpened for offer \(message.offerId.uuidString)")
            }
            try databaseService.updateOfferHavePublicKey(offerID: offerIDString, _chainID: chainIDString, _havePublicKey: true)
            logger.notice("handlePublicKeyAnnouncement: persistently set havePublicKeyTrue for offer \(message.offerId.uuidString)")
        } else {
            logger.notice("handlePublicKeyAnnouncement: interface ID of public key did not match that of offer \(message.offerId.uuidString) specified in announcement. Offer interface id: \(offer.interfaceId.base64EncodedString()), announcement interface id: \(message.publicKey.interfaceId.base64EncodedString())")
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of a `ServiceFeeRateChangedEvent`. Once notified, `OfferService` updates `offerTruthSource`'s `serviceFeeRate` with the value specified in `event`on the main thread.
     
     - Parameter event: The `ServiceFeeRateChangedEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError` if `offerTruthSource` is `nil`.
     */
    func handleServiceFeeRateChangedEvent(_ event: ServiceFeeRateChangedEvent) throws {
        logger.notice("handleServiceFeeRateChangedEvent: handling event. New rate: \(event.newServiceFeeRate)")
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handlePublicKeyAnnouncement call")
        }
        DispatchQueue.main.sync {
            offerTruthSource!.serviceFeeRate = event.newServiceFeeRate
        }
        logger.notice("handleServiceFeeRateChangedEvent: finished handling event. New rate: \(event.newServiceFeeRate)")
    }
    
}

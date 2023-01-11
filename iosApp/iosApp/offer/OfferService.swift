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
        - swapService: An object or struct adopting `SwapNotifiable` that this uses to handle [OfferTaken](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offertaken) events for offers made or taken by the user of this interface.
        - offerOpenedEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferOpenedEvent`s during `handleOfferOpenedEvent` calls.
        - offerEditedEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferEditedEvent`s during `handleOfferEditedEvent` calls.
        - offerCanceledEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferCanceledEvent`s during `handleOfferCanceledEvent` calls.
        - offerTakenEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferTakenEvent`s during `handleOfferTakenEvent` calls.
     */
    init(
        databaseService: DatabaseService,
        keyManagerService: KeyManagerService,
        swapService: SwapNotifiable,
        offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent> = BlockchainEventRepository<OfferOpenedEvent>(),
        offerEditedEventRepository: BlockchainEventRepository<OfferEditedEvent> = BlockchainEventRepository<OfferEditedEvent>(),
        offerCanceledEventRepository: BlockchainEventRepository<OfferCanceledEvent> = BlockchainEventRepository<OfferCanceledEvent>(),
        offerTakenEventRepository: BlockchainEventRepository<OfferTakenEvent> = BlockchainEventRepository<OfferTakenEvent>()
    ) {
        self.databaseService = databaseService
        self.keyManagerService = keyManagerService
        self.swapService = swapService
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
     An object adopting `SwapNotifiable` that `OfferService` uses to send taker information (for offers taken by the user of this interface) or to create `Swap` objects and await receiving taker information (for offers that have been taken and were made by the user of this interface).
     */
    private let swapService: SwapNotifiable
    
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
            /*
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
                    state: newOffer.state.asString,
                    cancelingOfferState: newOffer.cancelingOfferState.asString,
                    offerCancellationTransactionHash: newOffer.offerCancellationTransaction?.transactionHash,
                    offerCancellationTransactionCreationTime: nil,
                    offerCancellationTransactionCreationBlockNumber: nil,
                    editingOfferState: newOffer.editingOfferState.asString,
                    offerEditingTransactionHash: newOffer.offerEditingTransaction?.transactionHash,
                    offerEditingTransactionCreationTime: nil,
                    offerEditingTransactionCreationBlockNumber: nil
                )
                try databaseService.storeOffer(offer: newOfferForDatabase)
                var settlementMethodStrings: [(String, String?)] = []
                for settlementMethod in newOffer.settlementMethods {
                    settlementMethodStrings.append(((settlementMethod.onChainData ?? Data()).base64EncodedString(), settlementMethod.privateData))
                }
                logger.notice("openOffer: persistently storing \(settlementMethodStrings.count) settlement methods for offer \(newOffer.id.uuidString)")
                try databaseService.storeOfferSettlementMethods(offerID: newOfferForDatabase.id, _chainID: newOfferForDatabase.chainID, settlementMethods: settlementMethodStrings)
                if let afterPersistentStorage = afterPersistentStorage {
                    afterPersistentStorage()
                }
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
            */
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will call [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to open an offer.
     
     This calls `getServiceFeeRate` and then, on the global `DispatchQueue`, this calls `validateNewOfferData`, and uses the resulting `ValidatedOfferData` to calculate the transfer amount that must be approved. Then it calls `BlockchainService.createApproveTransferTransaction`, passing the stablecoin contract addess, the address of the CommutoSwap contract, and the calculated transfer amount, and pipes the result to the seal of the `Promise` this returns.
     
     
     - Parameters:
        - stablecoin: The contract address of the stablecoin for which the token transfer allowance will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which token transfer allowance will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - maximumAmount: The maximum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer, for which the token transfer allowance will be created.
        - direction: The direction of the new offer, for which the token transfer allowance will be created.
        - settlementMethods: The settlement methods of the new offer, for which the token transfer allowance will be created.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of approving a token transfer of the proper amount.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createApproveTokenTransferToOpenOfferTransaction(
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod]
    ) -> Promise<EthereumTransaction> {
        return Promise { seal in
            self.getServiceFeeRate()
                .done(on: DispatchQueue.global(qos: .userInitiated)) { [self] serviceFeeRate in
                    logger.notice("createApproveTokenTransferToOpenOfferTransaction: validating new offer data")
                    let validatedOfferData = try validateNewOfferData(
                        stablecoin: stablecoin,
                        stablecoinInformation: stablecoinInformation,
                        minimumAmount: minimumAmount,
                        maximumAmount: maximumAmount,
                        securityDepositAmount: securityDepositAmount,
                        serviceFeeRate: serviceFeeRate,
                        direction: direction,
                        settlementMethods: settlementMethods
                    )
                    let tokenAmountForOpeningOffer = validatedOfferData.securityDepositAmount + validatedOfferData.serviceFeeAmountUpperBound
                    logger.notice("createApproveTokenTransferToOpenOfferTransaction: creating for amount \(String(tokenAmountForOpeningOffer))")
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createOpenOfferAllowanceTransaction call")
                    }
                    blockchainService.createApproveTransferTransaction(tokenAddress: validatedOfferData.stablecoin, spender: blockchainService.commutoSwapAddress, amount: tokenAmountForOpeningOffer).pipe(to: seal.resolve)
                }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                    self.logger.error("createApproveTokenTransferToOpenOfferTransaction: encountered error: \(error.localizedDescription)")
                    seal.reject(error)
                }
        }
    }
    
    /**
     Attempts to call [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to open an offer.
     
     On the global `DispatchQueue`, this calls `validateNewOfferData` and uses the resulting `ValidatedNewOfferData` to determine the proper transfer amount to approve. Then, this creates another `EthereumTransaction` to approve such a transfer using this data, and then ensures that the data of this transaction matches the data of `approveTokenTransferToOpenOfferTransaction`. (If they do not match, then `approveTokenTransferToOpenOfferTransaction` was not created with the data supplied to this function.) Then, this generates and persistently a new `KeyPair` for this offer, creates a new offer ID and `Offer` object from the created `ValidatedNewOfferData` with state `OfferState.approvingTransfer`, and persistently stores this new `Offer`. Then this serializes and persistently stores the new settlement methods. Then this signs `approveTokenTransferToOpenOfferTransaction` and creates a `BlockchainTransaction` to wrap it. Then this persistently stores the token transfer approval data for said `BlockchainTransaction`, and persistently updates the token transfer approval state of the `Offer` to `TokenTransferApprovalState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Offer.approvingToOpenState` property of the `Offer` to `TokenTransferApprovalState.sendingTransaction`,  sets the `Offer.approvingToOpenTransaction` property of the `Offer` to said `BlockchainTransaction`, and adds the `Offer` to `offerTruthSource`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the approving to open state of the `Offer` to `TokenTransferApprovalState.awaitingTransactionConfirmation` and the state of the `Offer` to `OfferState.approveTransferTransactionSent`. Then, on the main `DispatchQueue`, this updates the `Offer.approvingToOpenState` property of the `Offer` to `TokenTransferApprovalState.awaitingTransactionConfirmation` and the `Offer.state` property of the `Offer` to `OfferState.approveTransferTransactionSent`.
     
     - Parameters:
        - chainID: The ID of the blockchain on which the token transfer allowance will be created.
        - stablecoin: The contract address of the stablecoin for which the token transfer allowance will be created.
        - stablecoinInformation: A `StablecoinInformation` about the stablecoin for which token transfer allowance will be created.
        - minimumAmount: The minimum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - maximumAmount: The maximum `Decimal` amount of the new offer, for which the token transfer allowance will be created.
        - securityDepositAmount: The security deposit `Decimal` amount for the new offer, for which the token transfer allowance will be created.
        - direction: The direction of the new offer, for which the token transfer allowance will be created.
        - settlementMethods: The settlement methods of the new offer, for which the token transfer allowance will be created.
        - approveTokenTransferToOpenOfferTransaction: An optional `EthereumTransaction` that can approve a token transfer for the proper amount.
     
     - Returns: An empty `Promise` that will be fulfilled when the token transfer is approved.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`, if `approveTokenTransferToOpenOfferTransaction` is `nil` or if `offerTruthSource` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `approveTokenTransferToOpenOfferTransaction` does not match that of the transaction this function creates using the supplied arguments. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func approveTokenTransferToOpenOffer(
        chainID: BigUInt,
        stablecoin: EthereumAddress?,
        stablecoinInformation: StablecoinInformation?,
        minimumAmount: Decimal,
        maximumAmount: Decimal,
        securityDepositAmount: Decimal,
        direction: OfferDirection,
        settlementMethods: [SettlementMethod],
        approveTokenTransferToOpenOfferTransaction: EthereumTransaction?
    ) -> Promise<Void> {
        return Promise { seal in
            self.getServiceFeeRate()
                .then(on: DispatchQueue.global(qos: .userInitiated)) { [self] serviceFeeRate -> Promise<(EthereumTransaction, ValidatedNewOfferData)> in
                    logger.notice("approveTokenTransferToOpenOffer: validating new offer data")
                    let validatedOfferData = try validateNewOfferData(
                        stablecoin: stablecoin,
                        stablecoinInformation: stablecoinInformation,
                        minimumAmount: minimumAmount,
                        maximumAmount: maximumAmount,
                        securityDepositAmount: securityDepositAmount,
                        serviceFeeRate: serviceFeeRate,
                        direction: direction,
                        settlementMethods: settlementMethods
                    )
                    let tokenAmountForOpeningOffer = validatedOfferData.securityDepositAmount + validatedOfferData.serviceFeeAmountUpperBound
                    logger.notice("approveTokenTransferToOpenOffer: recreating EthereumTransaction to approve transfer of \(String(tokenAmountForOpeningOffer)) tokens at contract \(validatedOfferData.stablecoin.address)")
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToOpenOffer call")
                    }
                    return blockchainService.createApproveTransferTransaction(tokenAddress: validatedOfferData.stablecoin, spender: blockchainService.commutoSwapAddress, amount: tokenAmountForOpeningOffer).map { ($0, validatedOfferData) }
                }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction, validatedOfferData -> Promise<(Offer, BlockchainTransaction)> in
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToOpenOffer call")
                    }
                    guard var approveTokenTransferToOpenOfferTransaction = approveTokenTransferToOpenOfferTransaction else {
                        throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during approveTokenTransferToOpenOffer call")
                    }
                    guard recreatedTransaction.data == approveTokenTransferToOpenOfferTransaction.data else {
                        throw OfferServiceError.nonmatchingDataError(desc: "Data of approveTokenTransferToOpenOfferTransaction did not match that of transaction created with supplied data")
                    }
                    logger.notice("approveTokenTransferToOpenOffer: creating new ID, Offer object and creating and persistently storing new key pair for new offer")
                    // Generate a new 2056 bit RSA key pair for the new offer
                    let newKeyPairForOffer = try keyManagerService.generateKeyPair(storeResult: true)
                    // Generate the a new ID for the offer
                    let newOfferID = UUID()
                    logger.notice("approveTokenTransferToOpenOffer: created ID \(newOfferID.uuidString) for new offer")
                    // Create a new Offer
                    #warning("TODO: get proper chain ID here and maker address")
                    let newOffer = Offer(
                        isCreated: true,
                        isTaken: false,
                        id: newOfferID,
                        maker: EthereumAddress("0x0000000000000000000000000000000000000000")!, // It is safe to use the zero address here, because the maker address will be automatically set to that of the function caller by CommutoSwap
                        interfaceID: newKeyPairForOffer.interfaceId,
                        stablecoin: validatedOfferData.stablecoin,
                        amountLowerBound: validatedOfferData.minimumAmount,
                        amountUpperBound: validatedOfferData.maximumAmount,
                        securityDepositAmount: validatedOfferData.securityDepositAmount,
                        serviceFeeRate: validatedOfferData.serviceFeeRate,
                        direction: validatedOfferData.direction,
                        settlementMethods: validatedOfferData.settlementMethods,
                        protocolVersion: BigUInt.zero,
                        chainID: chainID,
                        havePublicKey: true,
                        isUserMaker: true,
                        state: .approvingTransfer
                    )
                    logger.notice("approveTokenTransferToOpenOffer: persistently storing \(newOffer.id.uuidString)")
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
                        state: newOffer.state.asString,
                        approveToOpenState: newOffer.approvingToOpenState.asString,
                        approveToOpenTransactionHash: nil,
                        approveToOpenTransactionCreationTime: nil,
                        approveToOpenTransactionCreationBlockNumber: nil,
                        openingOfferState: newOffer.openingOfferState.asString,
                        openingOfferTransactionHash: nil,
                        openingOfferTransactionCreationTime: nil,
                        openingOfferTransactionCreationBlockNumber: nil,
                        cancelingOfferState: newOffer.cancelingOfferState.asString,
                        offerCancellationTransactionHash: nil,
                        offerCancellationTransactionCreationTime: nil,
                        offerCancellationTransactionCreationBlockNumber: nil,
                        editingOfferState: newOffer.editingOfferState.asString,
                        offerEditingTransactionHash: nil,
                        offerEditingTransactionCreationTime: nil,
                        offerEditingTransactionCreationBlockNumber: nil,
                        approveToTakeState: newOffer.approvingToTakeState.asString,
                        approveToTakeTransactionHash: nil,
                        approveToTakeTransactionCreationTime: nil,
                        approveToTakeTransactionCreationBlockNumber: nil,
                        takingOfferState: newOffer.takingOfferState.asString,
                        takingOfferTransactionHash: nil,
                        takingOfferTransactionCreationTime: nil,
                        takingOfferTransactionCreationBlockNumber: nil
                    )
                    try databaseService.storeOffer(offer: newOfferForDatabase)
                    logger.notice("approveTokenTransferToOpenOffer: serializing and persistently storing settlement methods for \(newOffer.id.uuidString)")
                    var settlementMethodStrings: [(String, String?)] = []
                    for settlementMethod in newOffer.settlementMethods {
                        settlementMethodStrings.append(((settlementMethod.onChainData ?? Data()).base64EncodedString(), settlementMethod.privateData))
                    }
                    logger.notice("approveTokenTransferToOpenOffer: persistently storing \(settlementMethodStrings.count) settlement methods for offer \(newOffer.id.uuidString)")
                    try databaseService.storeOfferSettlementMethods(offerID: newOfferForDatabase.id, _chainID: newOfferForDatabase.chainID, settlementMethods: settlementMethodStrings)
                    logger.notice("approveTokenTransferToOpenOffer: signing transaction for \(newOffer.id.uuidString)")
                    try blockchainService.signTransaction(&approveTokenTransferToOpenOfferTransaction)
                    let blockchainTransactionForApprovingTransfer = try BlockchainTransaction(transaction: approveTokenTransferToOpenOfferTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .approveTokenTransferToOpenOffer)
                    let dateString = DateFormatter.createDateString(blockchainTransactionForApprovingTransfer.timeOfCreation)
                    logger.notice("approveTokenTransferToOpenOffer: persistently storing approve transfer data for \(newOffer.id.uuidString), including tx hash \(blockchainTransactionForApprovingTransfer.transactionHash)")
                    try databaseService.updateOfferApproveToOpenData(offerID: newOffer.id.asData().base64EncodedString(), _chainID: String(newOffer.chainID), transactionHash: blockchainTransactionForApprovingTransfer.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForApprovingTransfer.latestBlockNumberAtCreation))
                    logger.notice("approveTokenTransferToOpenOffer: persistently updating approvingToOpenState for \(newOffer.id.uuidString) to sendingTransaction")
                    try databaseService.updateOfferApproveToOpenState(offerID: newOffer.id.asData().base64EncodedString(), _chainID: String(newOffer.chainID), state: TokenTransferApprovalState.sendingTransaction.asString)
                    logger.notice("approveTokenTransferToOpenOffer: updating approvingToOpenState for \(newOffer.id.uuidString) to sendingTransaction and storing tx \(blockchainTransactionForApprovingTransfer.transactionHash) in offer, then adding to offerTruthSource")
                    return Promise.value((newOffer, blockchainTransactionForApprovingTransfer))
                }.get(on: DispatchQueue.main) { offer, blockchainTransactionForApprovingTransfer in
                    offer.approvingToOpenState = .sendingTransaction
                    offer.approvingToOpenTransaction = blockchainTransactionForApprovingTransfer
                    guard var offerTruthSource = self.offerTruthSource else {
                        throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during approveTokenTransferToOpenOffer call")
                    }
                    offerTruthSource.offers[offer.id] = offer
                }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] offer, blockchainTransactionForApprovingTransfer -> Promise<(TransactionSendingResult, Offer)> in
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToOpenOffer call")
                    }
                    logger.notice("approveTokenTransferToOpenOffer: sending \(blockchainTransactionForApprovingTransfer.transactionHash) for \(offer.id.uuidString)")
                    return blockchainService.sendTransaction(blockchainTransactionForApprovingTransfer).map { ($0, offer) }
                }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, offer in
                    logger.notice("approveTokenTransferToOpenOffer: persistently updating approvingToOpenState of \(offer.id.uuidString) to awaitingTransactionConfirmation")
                    try databaseService.updateOfferApproveToOpenState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: TokenTransferApprovalState.awaitingTransactionConfirmation.asString)
                    logger.notice("approveTokenTransferToOpenOffer: persistently updating state of \(offer.id.uuidString) to approveTransferTransactionSent")
                    try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OfferState.approveTransferTransactionSent.asString)
                    logger.notice("approveTokenTransferToOpenOffer: updating state to approveTransferTransactionSent and approvingToOpenState to awaitingTransactionConfirmation for \(offer.id.uuidString)")
                }.get(on: DispatchQueue.main) { _, offer in
                    offer.state = .approveTransferTransactionSent
                    offer.approvingToOpenState = .awaitingTransactionConfirmation
                }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                    seal.fulfill(())
                }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                    logger.error("approveTokenTransferToOpenOffer: encountered error: \(error.localizedDescription)")
                    seal.reject(error)
                }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will open an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     This calls `validateOfferForOpening`, then creates an `OfferStruct` from `offer` and then calls `BlockchainService.createOpenOfferTransaction`, passing the `Offer.id` property of `offer` and the created `OfferStruct`.
     
     - Parameter offer: The `Offer` to be opened.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of opening `offer`.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func createOpenOfferTransaction(offer: Offer) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createOpenOfferTransaction: creating for \(offer.id.uuidString)")
                do {
                    try validateOfferForOpening(offer: offer)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createOpenOfferTransaction call"))
                    return
                }
                let offerStruct = offer.toOfferStruct()
                blockchainService.createOpenOfferTransaction(offerID: offer.id, offerStruct: offerStruct).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to open an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateOfferForOpening`, and then creates another `EthereumTransaction` to open `offer` and ensures that the data of this transaction matches the data of `offerOpeningTransaction`. (If they do not match, then `offerOpeningTransaction` was not created with the data contained in `offer`.) Then this signs `offerOpeningTransaction` and creates a `BlockchainTransaction` to wrap it. Then this persistently stores the offer opening data for said `BlockchainTransaction`, and persistently updates the offer opening state of `offer` to `OpeningOfferState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Offer.offerOpeningState` property of `offer` to `OpeningOfferState.sendingTransaction` and sets the `Offer.offerOpeningTransaction` property of `offer` to said `BlockchainTransaction`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the state of `offer` to `OfferState.openOfferTransactionSent` and the offer opening state of `Offer` to `OpeningOfferState.awaitingTransactionConfirmation`. Then, on the main `DispatchQueue`, this updates the `Offer.state` property of `offer` to `OfferState.openOfferTransactionSent` and the `Offer.openingOfferState` property of `offer` to `OpeningOfferState.awaitingTransactionConfirmation`.
     
     If this catches an error, it persistently updates the opening offer state of `offer` to `OpeningOfferState.error`, sets the `Offer.openingOfferError` property of `offer` to the caucht offer, and then, on the main `DispatchQueue`, sets the `Offer.openingOfferState` property of `offer` to `OpeningOfferState.error`.
     
     - Parameters:
        - offer: The `Offer` to open.
        - offerOpeningTransaction: An optional `EthereumTransaction` that can open `offer`.
     
     - Returns: An empty `Promise` that will be fulfilled when `offer` is opened.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil` or if `offerOpeningTransaction` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `offerOpeningTransaction` does not match that of the transaction this function creates using `offer`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func openOffer(offer: Offer, offerOpeningTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<EthereumTransaction> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("openOffer: opening \(offer.id.uuidString)")
                    do {
                        try validateOfferForOpening(offer: offer)
                    } catch {
                        seal.reject(error)
                    }
                    logger.notice("openOffer: recreating EthereumTransaction to open \(offer.id.uuidString) to ensure offerOpeningTransaction was created with the contents of offer")
                    guard let blockchainService = blockchainService else {
                        seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during openOffer call"))
                        return
                    }
                    blockchainService.createOpenOfferTransaction(offerID: offer.id, offerStruct: offer.toOfferStruct()).pipe(to: seal.resolve)
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction -> Promise<(BlockchainTransaction, BlockchainService)> in
                guard var offerOpeningTransaction = offerOpeningTransaction else {
                    throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during openOffer call for \(offer.id.uuidString)")
                }
                guard recreatedTransaction.data == offerOpeningTransaction.data else {
                    throw OfferServiceError.nonmatchingDataError(desc: "Data of offerOpeningTransaction did not match that of transaction created with offer \(offer.id.uuidString)")
                }
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during openOffer call")
                }
                logger.notice("openOffer: signing transaction for \(offer.id.uuidString)")
                try blockchainService.signTransaction(&offerOpeningTransaction)
                let blockchainTransactionForOfferOpening = try BlockchainTransaction(transaction: offerOpeningTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .openOffer)
                let dateString = DateFormatter.createDateString(blockchainTransactionForOfferOpening.timeOfCreation)
                logger.notice("openOffer: persistently storing offer opening data for \(offer.id.uuidString), including tx hash \(blockchainTransactionForOfferOpening.transactionHash)")
                try databaseService.updateOpeningOfferData(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), transactionHash: blockchainTransactionForOfferOpening.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForOfferOpening.latestBlockNumberAtCreation))
                logger.notice("openOffer: persistently updating openingOfferState for \(offer.id.uuidString) to \(OpeningOfferState.sendingTransaction.asString)")
                try databaseService.updateOpeningOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OpeningOfferState.sendingTransaction.asString)
                logger.notice("openOffer: updating openingOfferState to sendingTransaction and storing tx \(blockchainTransactionForOfferOpening.transactionHash) in \(offer.id.uuidString)")
                return Promise.value((blockchainTransactionForOfferOpening, blockchainService))
            }.get(on: DispatchQueue.main) { blockchainTransactionForOfferOpening, _ in
                offer.offerOpeningTransaction = blockchainTransactionForOfferOpening
                offer.openingOfferState = .sendingTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { offerOpeningBlockchainTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("openOffer: sending \(offerOpeningBlockchainTransaction.transactionHash) for \(offer.id.uuidString)")
                return blockchainService.sendTransaction(offerOpeningBlockchainTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("openOffer: persistently updating state of \(offer.id.uuidString) to \(OfferState.openOfferTransactionSent.asString)")
                try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OfferState.openOfferTransactionSent.asString)
                logger.notice("openOffer: persistently updating openingOfferState of \(offer.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateOpeningOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OpeningOfferState.awaitingTransactionConfirmation.asString)
                logger.notice("openOffer: updating state to \(OfferState.openOfferTransactionSent.asString) and openingOfferState to awaitingTransactionConfirmation for offer \(offer.id.uuidString)")
            }.get(on: DispatchQueue.main) { _ in
                offer.state = OfferState.openOfferTransactionSent
                offer.openingOfferState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("openOffer: encountered error while opening \(offer.id.uuidString), setting openingOfferState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the opening offer state isn't updated to error, then when the app restarts, we will check the offer opening transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateOpeningOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OpeningOfferState.error.asString)
                } catch {}
                offer.openingOfferError = error
                DispatchQueue.main.async {
                    offer.openingOfferState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    #warning("TODO: Delete this function once new cancelOffer code via new pipeline is fully implemented and tested")
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
                        //try databaseService.updateOfferState(offerID: offerID.asData().base64EncodedString(), _chainID: String(chainID), state: OfferState.canceling.asString)
                        logger.notice("cancelOffer: updating offer \(offerID.uuidString) state to canceling")
                        seal.fulfill(())
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { _ in
                //self.offerTruthSource?.offers[offerID]?.state = .canceling
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ -> Promise<Void> in
                logger.notice("cancelOffer: canceling offer \(offerID.uuidString) on chain")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during cancelOffer call")
                }
                return blockchainService.cancelOffer(offerID: offerID)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("cancelOffer: persistently updating offer \(offerID.uuidString) state to cancelOfferTxBroadcast")
                do {
                    //try databaseService.updateOfferState(offerID: offerID.asData().base64EncodedString(), _chainID: String(chainID), state: OfferState.cancelOfferTransactionBroadcast.asString)
                    logger.notice("cancelOffer: updating offer \(offerID.uuidString) state to cancelOfferTxBroadcast")
                }
            }.get(on: DispatchQueue.main) { _ in
                //self.offerTruthSource?.offers[offerID]?.state = .cancelOfferTransactionBroadcast
            }.done(on: DispatchQueue.global(qos: .userInitiated)) {
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("cancelOffer: encountered error while canceling \(offerID.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateOfferForCancellation`, and then calls `BlockchainService.createCancelOfferTransaction`, passing the `Offer.id` and `Offer.chainID` properties of `offer`, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameter offer: The `Offer` to be canceled.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of cancelling `offer`.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createCancelOfferTransaction(offer: Offer) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createCancelOfferTransaction: creating for \(offer.id.uuidString)")
                do {
                    try validateOfferForCancellation(offer: offer)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createCancelOfferTransaction call"))
                    return
                }
                blockchainService.createCancelOfferTransaction(offerID: offer.id, chainID: offer.chainID).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to cancel an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateOfferForCancellation` and ensures that `offerCancellationTransaction` is not `nil`. Then it signs `offerCancellationTransaction`, creates a `BlockchainTransaction` to wrap it, determines the transaction hash, persistently stores the transaction hash and persistently updates the `Offer.cancelingOfferState` of the offer being canceled to `CancelingOfferState.sendingTransaction`. Then, on the main `DispatchQueue`, this stores the transaction hash in `offer` and sets `offer`'s `Offer.cancelingOfferState` property to `CancelingOfferState.sendingTransaction`. Then, on the global `DispatchQueue` it sends the `BlockchainTransaction`-wrapped `offerCancellationTransaction` to the blockchain. Once a response is received, this persistently updates the `Offer.cancelingOfferState` of the offer being canceled to `CancelingOfferState.awaitingTransactionConfirmation`. Then, on the main `DispatchQueue`, this sets the value of `offer`'s `Offer.cancelingOfferState` to `CancelingOfferState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - offer: The `Offer` being canceled.
        - offerCancellationTransaction: An optional `EthereumTransaction` that can cancel `offer`.
     
     - Returns: An empty `Promise` that will be fulfilled when `offer` is canceled.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `offerCancellationTransaction` or `blockchainService` are `nil`. Because this function returns a `Promise`, these errors will not actually be thrown, but will be passed to `seal.reject`.
     */
    func cancelOffer(offer: Offer, offerCancellationTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<(BlockchainTransaction, BlockchainService)> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("cancelOffer: canceling \(offer.id.uuidString)")
                    do {
                        try validateOfferForCancellation(offer: offer)
                    } catch {
                        seal.reject(error)
                    }
                    do {
                        guard var offerCancellationTransaction = offerCancellationTransaction else {
                            throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during cancelOffer call for \(offer.id.uuidString)")
                        }
                        guard let blockchainService = blockchainService else {
                            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during cancelOffer call for \(offer.id.uuidString)")
                        }
                        logger.notice("cancelOffer: signing transaction for \(offer.id.uuidString)")
                        try blockchainService.signTransaction(&offerCancellationTransaction)
                        let blockchainTransactionForOfferCancellation = try BlockchainTransaction(transaction: offerCancellationTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .cancelOffer)
                        let dateString = DateFormatter.createDateString(blockchainTransactionForOfferCancellation.timeOfCreation)
                        logger.notice("cancelOffer: persistently storing offer cancellation data for \(offer.id.uuidString), including tx hash \(blockchainTransactionForOfferCancellation.transactionHash)")
                        try databaseService.updateOfferCancellationData(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), transactionHash: blockchainTransactionForOfferCancellation.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForOfferCancellation.latestBlockNumberAtCreation))
                        logger.notice("cancelOffer: persistently updating cancelingOfferState for \(offer.id.uuidString) to sendingTransaction")
                        try databaseService.updateCancelingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: CancelingOfferState.sendingTransaction.asString)
                        logger.notice("cancelOffer: updating cancelingOfferState for \(offer.id.uuidString) to sendingTransaction and storing tx hash \(blockchainTransactionForOfferCancellation.transactionHash) in offer")
                        seal.fulfill((blockchainTransactionForOfferCancellation, blockchainService))
                    } catch {
                        seal.reject(error)
                    }
                }
            }.get(on: DispatchQueue.main) { offerCancellationTransaction, _ in
                offer.cancelingOfferState = .sendingTransaction
                offer.offerCancellationTransaction = offerCancellationTransaction
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { offerCancellationTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("cancelOffer: sending \(offerCancellationTransaction.transactionHash) for \(offer.id.uuidString)")
                return blockchainService.sendTransaction(offerCancellationTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("cancelOffer: persistently updating cancelingOfferState of \(offer.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateCancelingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: CancelingOfferState.awaitingTransactionConfirmation.asString)
                logger.notice("cancelOffer: updating cancelingOfferState for \(offer.id.uuidString) to awaitingTransactionConfirmation")
            }.get(on: DispatchQueue.main) { _ in
                offer.cancelingOfferState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("cancelOffer: encountered error while canceling \(offer.id.uuidString), setting cancelingOfferState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the canceling offer state isn't updated to error, then when the app restarts, we will check the offer cancelation transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateCancelingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: CancelingOfferState.error.asString)
                } catch {}
                offer.cancelingOfferError = error
                DispatchQueue.main.async {
                    offer.cancelingOfferState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this serializes the new settlement methods, saves them and their private data persistently as pending settlement methods, and calls the CommutoSwap contract's [editOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#edit-offer) function, passing the offer ID and an `OfferStruct` containing the new serialized settlement methods.
     
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
                        let serializedSettlementMethodsAndPrivateDetails = try newSettlementMethods.compactMap { settlementMethod in
                            return (try JSONEncoder().encode(settlementMethod).base64EncodedString(), settlementMethod.privateData)
                        }
                        logger.notice("editOffer: persistently storing pending settlement methods for \(offerID.uuidString)")
                        try databaseService.storePendingOfferSettlementMethods(offerID: offerID.asData().base64EncodedString(), _chainID: String(offer.chainID), pendingSettlementMethods: serializedSettlementMethodsAndPrivateDetails)
                        let onChainSettlementMethods = serializedSettlementMethodsAndPrivateDetails.compactMap { serializedSettlementMethodWithDetails in
                            return Data(base64Encoded: serializedSettlementMethodWithDetails.0)
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
                self.logger.error("editOffer: encountered error while editing \(offerID.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface, using the settlement methods contained in `newSettlementMethods`.
     
     This calls `validateOfferForEditing`, and then this serializes `newSettlementMethods` and obtains the desired on-chain data from the serialized result, creates an `OfferStruct` with these results and then calls `BlockchainService.createEditOfferTransaction`, passing the `Offer.id`, `Offer.chainID` properties of `offer` and the created `OfferStruct`.
     
     - Parameters:
        - offer: The `Offer` to be edited.
        - newSettlementMethods: The new `SettlementMethod`s with which the offer will be updated.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of editing `offer` using the settlement methods contained in `newSettlementMethods`.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil` or if settlement method serialization does not fail but `onChainSettlementMethods` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func createEditOfferTransaction(offer: Offer, newSettlementMethods: [SettlementMethod]) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createEditOfferTransaction: creating for \(offer.id.uuidString)")
                do {
                    try validateOfferForEditing(offer: offer)
                } catch {
                    seal.reject(error)
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createEditOfferTransaction call"))
                    return
                }
                var onChainSettlementMethods: [Data]? = nil
                do {
                    logger.notice("createEditOfferTransaction: serializing settlement methods for \(offer.id.uuidString)")
                    let serializedSettlementMethodsAndPrivateDetails = try newSettlementMethods.compactMap { settlementMethod in
                        return (try JSONEncoder().encode(settlementMethod).base64EncodedString(), settlementMethod.privateData)
                    }
                    onChainSettlementMethods = serializedSettlementMethodsAndPrivateDetails.compactMap { serializedSettlementMethodWithDetails in
                        return Data(base64Encoded: serializedSettlementMethodWithDetails.0)
                    }
                } catch {
                    self.logger.error("createEditOfferTransaction: encountered error serializing settlement methods for \(offer.id.uuidString): \(error.localizedDescription)")
                    seal.reject(error)
                }
                guard let onChainSettlementMethods = onChainSettlementMethods else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "Unexpectedly got nil onChainSettlementMethods during createEditOfferTransaction call but serialization did not fail"))
                    return
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
                logger.notice("createEditOfferTransaction: creating for \(offer.id.uuidString)")
                blockchainService.createEditOfferTransaction(offerID: offer.id, chainID: offer.chainID, offerStruct: offerStruct).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to edit an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `validateOfferForEditing` and ensures that `newSettlementMethods` can be serialized. Then, this creates another `EthereumTransaction` to edit `offer` using the serialized settlement method data, and then ensures that the data of this transaction matches the data of `offerEditingTransaction`. (If they do not match, then `offerEditingTransaction` was not created with the settlement methods contained in `newSettlementMethods`.) Then this signs `offerEditingTransaction` and creates a `BlockchainTransaction` to wrap it. Then this persistently stores the offer editing data for said `BlockchainTransaction`, persistently stores the pending settlement methods, and persistently updates the editing offer state of `offer` to `EditingOfferState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Offer.editingOfferState` property of `offer` to `EditingOfferState.sendingTransaction` and sets the `Offer.offerEditingTransaction` property of `offer` to said `BlockchainTransaction`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the editing offer state of `offer` to `EditingOfferState.awaitingTransactionConfirmation`, then on the main `DispatchQueue` updates the `Offer.editingOfferState` property of `offer` to `EditingOfferState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - offer: The `Offer` being edited.
        - newSettlementMethods: The `SettlementMethod`s with which `offerEditingTransaction` should have been made, and with which `offer` will be edited.
        - offerEditingTransaction: An optional `EthereumTransaction` that can edit `offer` using the `SettlementMethod`s contained in `newSettlementMethods`.
     
     - Returns: An empty `Promise` that will be fulfilled when `offer` is edited.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil` or if `offerEditingTransaction` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `offerEditingTransaction` does not match that of the transaction this function creates using `newSettlementMethods`. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func editOffer(offer: Offer, newSettlementMethods: [SettlementMethod], offerEditingTransaction: EthereumTransaction?) -> Promise<Void> {
        return Promise { seal in
            Promise<Array<(String, String?)>> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("editOffer: editing \(offer.id.uuidString)")
                    do {
                        try validateOfferForEditing(offer: offer)
                    } catch {
                        seal.reject(error)
                    }
                    do {
                        logger.notice("editOffer: serializing settlement methods for \(offer.id.uuidString)")
                        let serializedSettlementmethodsAndPrivateDetails = try newSettlementMethods.compactMap { settlementMethod in
                            return (try JSONEncoder().encode(settlementMethod).base64EncodedString(), settlementMethod.privateData)
                        }
                        seal.fulfill(serializedSettlementmethodsAndPrivateDetails)
                    } catch {
                        logger.error("editOffer: encountered error serializing settlement methods for \(offer.id.uuidString): \(error.localizedDescription)")
                        seal.reject(error)
                    }
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] serializedSettlementMethodsAndPrivateDetails -> Promise<(EthereumTransaction, Array<(String, String?)>)> in
                logger.notice("editOffer: recreating EthereumTransaction to edit \(offer.id.uuidString) to ensure offerEditingTransaction was created with the contents of newSettlementMethods")
                let onChainSettlementMethods = serializedSettlementMethodsAndPrivateDetails.compactMap { serializedSettlementMethodWithDetails in
                    return Data(base64Encoded: serializedSettlementMethodWithDetails.0)
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
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during editOffer call for \(offer.id.uuidString) during transaction recreation")
                }
                return blockchainService.createEditOfferTransaction(offerID: offer.id, chainID: offer.chainID, offerStruct: offerStruct).map { ($0, serializedSettlementMethodsAndPrivateDetails) }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedOfferEditingTransaction, serializedSettlementMethodsAndPrivateDetails -> Promise<(BlockchainTransaction, BlockchainService)> in
                guard var offerEditingTransaction = offerEditingTransaction else {
                    throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during editOffer call for \(offer.id.uuidString)")
                }
                guard recreatedOfferEditingTransaction.data == offerEditingTransaction.data else {
                    throw OfferServiceError.nonmatchingDataError(desc: "Data of offerEditingTransaction did not match that of transaction created with newSettlementMethods")
                }
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during editOffer call for \(offer.id.uuidString) during settlement method storage")
                }
                logger.notice("editOffer: signing transaction for \(offer.id.uuidString)")
                try blockchainService.signTransaction(&offerEditingTransaction)
                let blockchainTransactionForOfferEditing = try BlockchainTransaction(transaction: offerEditingTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .editOffer)
                let dateString = DateFormatter.createDateString(blockchainTransactionForOfferEditing.timeOfCreation)
                logger.notice("editOffer: persistently storing offer editing data for \(offer.id.uuidString), including tx hash \(blockchainTransactionForOfferEditing.transactionHash)")
                try databaseService.updateOfferEditingData(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), transactionHash: blockchainTransactionForOfferEditing.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForOfferEditing.latestBlockNumberAtCreation))
                #warning("TODO: persistently store new settlement methods along with hash of transaction for offer editing here, rather than offer ID and chain ID")
                try databaseService.storePendingOfferSettlementMethods(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), pendingSettlementMethods: serializedSettlementMethodsAndPrivateDetails)
                logger.notice("editOffer: persistently updating editingOfferState for \(offer.id.uuidString) to sendingTransaction")
                try databaseService.updateEditingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: EditingOfferState.sendingTransaction.asString)
                logger.notice("editOffer: updating editingOfferState for \(offer.id.uuidString) to sendingTransaction and storing tx \(blockchainTransactionForOfferEditing.transactionHash) in offer")
                return Promise.value((blockchainTransactionForOfferEditing, blockchainService))
            }.get(on: DispatchQueue.main) { blockchainTransactionForOfferEditing, _ in
                offer.editingOfferState = .sendingTransaction
                offer.offerEditingTransaction = blockchainTransactionForOfferEditing
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { offerEditingBlockchainTransaction, blockchainService -> Promise<TransactionSendingResult> in
                self.logger.notice("editOffer: sending \(offerEditingBlockchainTransaction.transactionHash) for \(offer.id.uuidString)")
                return blockchainService.sendTransaction(offerEditingBlockchainTransaction)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("editOffer: persistently updating editingOfferState of \(offer.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateEditingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: EditingOfferState.awaitingTransactionConfirmation.asString)
                logger.notice("editOffer: updating editingOfferState for \(offer.id.uuidString) to awaitingTransactionConfirmation")
            }.get(on: DispatchQueue.main) { _ in
                offer.editingOfferState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("editOffer: encountered error while editing \(offer.id.uuidString), setting editingOfferState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the editing offer state isn't updated to error, then when the app restarts, we will check the offer editing transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateEditingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: EditingOfferState.error.asString)
                } catch {}
                offer.editingOfferError = error
                DispatchQueue.main.async {
                    offer.editingOfferState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will call [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to take an offer.
     
     On the global `DispatchQueue`, this calls `validateNewSwapData`, and uses the resulting `ValidatedNewSwapData` to calculate the transfer amount that must be approved. Then it calls `BlockchainService.createApproveTransferTransaction`, passing the stablecoin contract addess specified in `offerToTake`, the address of the CommutoSwap contract, and the calculated transfer amount, and pipes the result to the seal of the `Promise` this returns.
     
     - Parameters:
        - offerToTake: The offer that will be taken, for which this token transfer approval transaction is being created.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - stablecoinInformationRepository: A `StablecoinInformationRepository` containing information for the stablecoin address-chain ID pair specified by `offerToTake`.
     
     - Returns: A `Promise` wrapped around an `EthereumTransaction` capable of approving a token transfer of the proper amount.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if the `validateNewSwapData` does not throw but somehow does not create a `ValidatedNewSwapData` or if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createApproveTokenTrasferToTakeOfferTransaction(
        offerToTake: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        stablecoinInformationRepository: StablecoinInformationRepository
    ) -> Promise<EthereumTransaction> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createApproveTokenTrasferToTakeOfferTransaction: creating for \(offerToTake.id)")
                var validatedSwapData: ValidatedNewSwapData? = nil
                do {
                    validatedSwapData = try validateNewSwapData(
                        offer: offerToTake,
                        takenSwapAmount: takenSwapAmount,
                        selectedMakerSettlementMethod: makerSettlementMethod,
                        selectedTakerSettlementMethod: takerSettlementMethod,
                        stablecoinInformationRepository: stablecoinInformationRepository
                    )
                } catch {
                    seal.reject(error)
                    return
                }
                guard let validatedSwapData = validatedSwapData else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "validatedSwapData was nil but validateNewSwapData did not throw for \(offerToTake.id) in createApproveTokenTrasferToTakeOfferTransaction call"))
                    return
                }
                let serviceFeeAmount = (validatedSwapData.takenSwapAmount * offerToTake.serviceFeeRate) / BigUInt(10_000)
                var tokenAmountForTakingOffer: BigUInt {
                    switch (offerToTake.direction) {
                    case .buy:
                        // We are taking a BUY offer, so we are SELLING stablecoin. Therefore we must authorize a transfer equal to the taken swap amount, the security deposit amount, and the service fee amount to the CommutoSwap contract.
                        return validatedSwapData.takenSwapAmount + offerToTake.securityDepositAmount + serviceFeeAmount
                    case .sell:
                        // We are taking a SELL offer, so we are BUYING stablecoin. Therefore we must authorize a transfer equal to the security deposit amount and the service fee amount to the CommutoSwap contract.
                        return offerToTake.securityDepositAmount + serviceFeeAmount
                    }
                }
                guard let blockchainService = blockchainService else {
                    seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createApproveTokenTrasferToTakeOfferTransaction call"))
                    return
                }
                blockchainService.createApproveTransferTransaction(
                    tokenAddress: offerToTake.stablecoin,
                    spender: blockchainService.commutoSwapAddress,
                    amount: tokenAmountForTakingOffer
                ).pipe(to: seal.resolve)
            }
        }
    }
    
    /**
     Attempts to call [approve](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) on an ERC20 contract in order to take an offer.
     
     On the global `DispatchQueue`, this calls `validateNewSwapData` and uses the resulting `ValidatedNewSwapData` to determine the proper transfer amount to approve. Then, this creates another `EthereumTransaction` to approve such a transfer using this data, and then ensures that the data of this transaction matches the data of `approveTokenTransferToTakeOfferTransaction`. (If they do not match, then `approveTokenTransferToTakeOfferTransaction` was not created with the data supplied to this function.) Then this signs `approveTokenTransferToTakeOfferTransaction` and creates a `BlockchainTransaction` to wrap it. Then this persistently stores the token transfer approval data for said `BlockchainTransaction` and persistently updates the token transfer approval state of `offerToTake` to `TokenTransferApprovalState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Offer.approvingToTakeState` property of `offerToTake` to `TokenTransferApprovalState.sendingTransaction` and sets the `Offer.approvingToTakeTransaction` property of `offerToTake` to said `BlockchainTransaction`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the approving to take state of the `Offer` to `TokenTransferApprovalState.awaitingTransactionConfirmation`. Then, on the main `DispatchQueue`, this updates the `Offer.approvingToTakeState` property of the `Offer` to `TokenTransferApprovalState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - offerToTake: The offer that will be taken, for which this is approving a token transfer.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - stablecoinInformationRepository: A `StablecoinInformationRepository` containing information for the stablecoin address-chain ID pair specified by `offerToTake`.
        - approveTokenTransferToTakeOfferTransaction: An optional `EthereumTransaction` that can approve a token transfer for the proper amount.
     
     - Returns: An empty `Promise` that will be fulfilled when the token transfer is approved.
     
     - Throws: An `OfferService.offerNotAvailableError` if `offerToTake` is not in the `OfferState.offerOpened` state, an `OfferServiceError.unexpectedNilError` if the `validateNewSwapData` does not throw but somehow does not create a `ValidatedNewSwapData`, if `blockchainService` is `nil`, if `approveTokenTransferToTakeOfferTransaction` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `approveTokenTransferToTakeOfferTransaction` does not match that of the transaction this function creates using the supplied arguments. Note that because this function returns a `Promise`, this error will not actually be thrown but will be passed to `seal.reject`.
     */
    func approveTokenTransferToTakeOffer(
        offerToTake: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        stablecoinInformationRepository: StablecoinInformationRepository,
        approveTokenTransferToTakeOfferTransaction: EthereumTransaction?
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<(EthereumTransaction, ValidatedNewSwapData)> { seal in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.notice("approveTokenTransferToTakeOffer: validating new swap data for \(offerToTake.id)")
                    var validatedSwapData: ValidatedNewSwapData? = nil
                    do {
                        guard offerToTake.state == .offerOpened else {
                            throw OfferServiceError.offerNotAvailableError(desc: "This Offer cannot currently be taken.")
                        }
                        validatedSwapData = try validateNewSwapData(
                            offer: offerToTake,
                            takenSwapAmount: takenSwapAmount,
                            selectedMakerSettlementMethod: makerSettlementMethod,
                            selectedTakerSettlementMethod: takerSettlementMethod,
                            stablecoinInformationRepository: stablecoinInformationRepository
                        )
                    } catch {
                        seal.reject(error)
                        return
                    }
                    guard let validatedSwapData = validatedSwapData else {
                        seal.reject(OfferServiceError.unexpectedNilError(desc: "validatedSwapData was nil but validateNewSwapData did not throw for \(offerToTake.id) in approveTokenTransferToTakeOffer call"))
                        return
                    }
                    let serviceFeeAmount = (validatedSwapData.takenSwapAmount * offerToTake.serviceFeeRate) / BigUInt(10_000)
                    var tokenAmountForTakingOffer: BigUInt {
                        switch (offerToTake.direction) {
                        case .buy:
                            // We are taking a BUY offer, so we are SELLING stablecoin. Therefore we must authorize a transfer equal to the taken swap amount, the security deposit amount, and the service fee amount to the CommutoSwap contract.
                            return validatedSwapData.takenSwapAmount + offerToTake.securityDepositAmount + serviceFeeAmount
                        case .sell:
                            // We are taking a SELL offer, so we are BUYING stablecoin. Therefore we must authorize a transfer equal to the security deposit amount and the service fee amount to the CommutoSwap contract.
                            return offerToTake.securityDepositAmount + serviceFeeAmount
                        }
                    }
                    logger.notice("approveTokenTransferToTakeOffer: recreating EthereumTransaction to approve transfer of \(String(tokenAmountForTakingOffer)) tokens at contract \(offerToTake.stablecoin.address)")
                    guard let blockchainService = blockchainService else {
                        seal.reject(OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToTakeOffer call"))
                        return
                    }
                    blockchainService.createApproveTransferTransaction(
                        tokenAddress: offerToTake.stablecoin,
                        spender: blockchainService.commutoSwapAddress,
                        amount: tokenAmountForTakingOffer
                    ).map({ ($0, validatedSwapData) }).pipe(to: seal.resolve)
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction, validatedSwapData -> Promise<(BlockchainTransaction)> in
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToTakeOffer call")
                }
                guard var approveTokenTransferToTakeOfferTransaction = approveTokenTransferToTakeOfferTransaction else {
                    throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during approveTokenTransferToTakeOffer call")
                }
                guard recreatedTransaction.data == approveTokenTransferToTakeOfferTransaction.data else {
                    throw OfferServiceError.nonmatchingDataError(desc: "Data of approveTokenTransferToTakeOfferTransaction did not match that of transaction created with supplied data")
                }
                logger.notice("approveTokenTransferToTakeOffer: signing transaction for \(offerToTake.id.uuidString)")
                try blockchainService.signTransaction(&approveTokenTransferToTakeOfferTransaction)
                let blockchainTransactionForApprovingTransfer = try BlockchainTransaction(transaction: approveTokenTransferToTakeOfferTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .approveTokenTransferToTakeOffer)
                let dateString = DateFormatter.createDateString(blockchainTransactionForApprovingTransfer.timeOfCreation)
                logger.notice("approveTokenTransferToTakeOffer: persistently storing approve transfer data for \(offerToTake.id.uuidString), including tx hash \(blockchainTransactionForApprovingTransfer.transactionHash)")
                try databaseService.updateOfferApproveToTakeData(
                    offerID: offerToTake.id.asData().base64EncodedString(),
                    _chainID: String(offerToTake.chainID),
                    transactionHash: blockchainTransactionForApprovingTransfer.transactionHash,
                    transactionCreationTime: dateString,
                    latestBlockNumberAtCreationTime: Int(blockchainTransactionForApprovingTransfer.latestBlockNumberAtCreation)
                )
                logger.notice("approveTokenTransferToTakeOffer: persistently updating approveToTakeState for \(offerToTake.id.uuidString) to sendingTransaction")
                try databaseService.updateOfferApproveToTakeState(
                    offerID: offerToTake.id.asData().base64EncodedString(),
                    _chainID: String(offerToTake.chainID),
                    state: TokenTransferApprovalState.sendingTransaction.asString
                )
                logger.notice("approveTokenTransferToTakeOffer: updating approvingToTakeState for \(offerToTake.id.uuidString) to sendingTransaction and storing tx \(blockchainTransactionForApprovingTransfer.transactionHash) in offer, then adding to offerTruthSource")
                return Promise.value(blockchainTransactionForApprovingTransfer)
            }.get(on: DispatchQueue.main) { blockchainTransactionForApprovingTransfer in
                offerToTake.approvingToTakeState = .sendingTransaction
                offerToTake.approvingToTakeTransaction = blockchainTransactionForApprovingTransfer
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] blockchainTransactionForApprovingTransfer -> Promise<TransactionSendingResult> in
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during approveTokenTransferToTakeOffer call")
                }
                logger.notice("approveTokenTransferToTakeOffer: sending \(blockchainTransactionForApprovingTransfer.transactionHash) for \(offerToTake.id.uuidString)")
                return blockchainService.sendTransaction(blockchainTransactionForApprovingTransfer)
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _ in
                logger.notice("approveTokenTransferToTakeOffer: persistently updating approvingToTakeState of \(offerToTake.id.uuidString) to awaitingTransactionConfirmation")
                try databaseService.updateOfferApproveToTakeState(
                    offerID: offerToTake.id.asData().base64EncodedString(),
                    _chainID: String(offerToTake.chainID),
                    state: TokenTransferApprovalState.awaitingTransactionConfirmation.asString
                )
                logger.notice("approveTokenTransferToTakeOffer: updating approvingToTakeState to awaitingTransactionConfirmation for \(offerToTake.id.uuidString)")
            }.get(on: DispatchQueue.main) { _ in
                offerToTake.approvingToTakeState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("approveTokenTransferToTakeOffer: encountered error: \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     Attempts to create an `EthereumTransaction` that will take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     
     On the global `DispatchQueue`, this creates, but does not persistently store, a new `KeyPair`, and then calls `createNewSwap`, passing all supplied data as well as this new `KeyPair`. Then this calls `BlockchainService.createTakeOfferTransaction`, passing the `Offer.id` property of `offerToTake` and a `SwapStruct` created from the `Swap` returned by the `createNewSwap` call, maps the result to a pair in which the second element is the created `KeyPair`, and then pipes the result to the seal of the `Promise` this returns.
     
     - Parameters:
        - offerToTake: The offer that will be taken, for which this token transfer approval transaction is being created.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - stablecoinInformationRepository: A `StablecoinInformationRepository` containing information for the stablecoin address-chain ID pair specified by `offerToTake`.
     
     - Returns: A `Promise` wrapped around a pair containing an `EthereumTransaction` capable of taking `offerToTake` with the supplied data, along with a `KeyPair` belonging to the user/taker, from which the taker's interface ID is obtained.
    
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`. Note that because this function returns a `Promise`, this error will not actually be thrown, but will be passed to `seal.reject`.
     */
    func createTakeOfferTransaction(
        offerToTake: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        stablecoinInformationRepository: StablecoinInformationRepository
    ) -> Promise<(EthereumTransaction, KeyPair)> {
        return Promise { seal in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                logger.notice("createTakeOfferTransaction: creating for \(offerToTake.id)")
                do {
                    logger.notice("createTakeOfferTransaction: creating new key pair for \(offerToTake.id.uuidString)")
                    // Generate a new 2056 bit RSA key pair to take the swap, but DON'T store it yet in case the user decides not to take the swap
                    let keyPair = try keyManagerService.generateKeyPair(storeResult: false)
                    let newSwap = try createNewSwap(
                        offerToTake: offerToTake,
                        takenSwapAmount: takenSwapAmount,
                        makerSettlementMethod: makerSettlementMethod,
                        takerSettlementMethod: takerSettlementMethod,
                        stablecoinInformationRepository: stablecoinInformationRepository,
                        takerKeyPair: keyPair
                    )
                    let swapStruct = newSwap.toSwapStruct()
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createTakeOfferTransaction call for \(offerToTake.id.uuidString)")
                    }
                    blockchainService.createTakeOfferTransaction(offerID: offerToTake.id, swapStruct: swapStruct).map { ($0, keyPair) }.pipe(to: seal.resolve)
                } catch {
                    seal.reject(error)
                    return
                }
            }
        }
    }
    
    /**
     Attempts to take an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer) NOT made by the user of this interface.
     
     On the global `DispatchQueue`, this calls `createNewSwap`, and then uses the resulting data to create another `EthereumTransaction` to open `offerToTake` and ensures that the data of this transaction matches the data of `offerTakingTransaction`. (If they do not match, then `offerTakingTransaction` was not created with the data contained in `offer`.) Then this persistently stores `takerKeyPair` and the `Swap` obtained from the `createNewSwap` call. Then this signs `offerTakingTransaction` and creates a `BlockchainTransaction` to wrap it. Then this persistently stores the offer taking data for said `BlockchainTransaction`, and persistently updates the offer taking state of `offerToTake` to `TakingOfferState.sendingTransaction`. Then, on the main `DispatchQueue`, this updates the `Offer.takingOfferState` property of `offer` to `TakingOfferState.sendingTransaction` and sets the `Offer.takingOfferTransaction` property of `offerToTake` to said `BlockchainTransaction`, and adds the `Swap` to `swapTruthSource`. Then, on the global `DispatchQueue`, this calls `BlockchainService.sendTransaction`, passing said `BlockchainTransaction`. When this call returns, this persistently updates the state of the `Swap` to `SwapState.takeOfferTransactionSent`, persistently updates the taking offer state of `offerToTake` to `TakingOfferState.awaitingTransactionConfirmation`, and then on the main `DispatchQueue`, updates the state of the `Swap` to `SwapState.takeOfferTransactionSent` and the `Offer.takingOfferState` of `offerToTake` to `TakingOfferState.awaitingTransactionConfirmation`.
     
     - Parameters:
        - offerToTake: The offer that will be taken.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - stablecoinInformationRepository: A `StablecoinInformationRepository` containing information for the stablecoin address-chain ID pair specified by `offerToTake`.
        - takerKeyPair: A `KeyPair` created by this interface, from which the taker interface ID used in `offerTakingTransaction` was derived, and which will thus be used as the taker's key pair when taking `offerToTake`.
        - offerTakingTransaction: An optional `EthereumTransaction` that can take `offerToTake` using the supplied data.
     
     - Returns: An empty `Promise` that will be fulfilled when the offer is taken.
     
     - Throws: An `OfferServiceError.offerNotAvailableError` if `offerToTake` is not in the `OfferState.offerOpened` state, if the `Offer.approvingToTakeState` property of `offerToTake` is not `TokenTransferApprovalState.completed`, or if the `Offer.takingOfferState` property of `offerToTake` is not `TakingOfferState.none`, `TakingOfferState.validating` or `TakingOfferState.error`, an `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`, if `offerTakingTransaction` is `nil`, if `takerKeyPair` is `nil` or if `swapTruthSource` is `nil`, or an `OfferServiceError.nonmatchingDataError` if the data of `offerTakingTransaction` does not match that of the transaction this function creates using the supplied arguments.
     */
    func takeOffer(
        offerToTake: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        stablecoinInformationRepository: StablecoinInformationRepository,
        takerKeyPair: KeyPair?,
        offerTakingTransaction: EthereumTransaction?
    ) -> Promise<Void> {
        return Promise { seal in
            Promise<(EthereumTransaction, Swap)> { seal in
                logger.notice("takeOffer: taking \(offerToTake.id.uuidString)")
                do {
                    guard offerToTake.state == .offerOpened else {
                        throw OfferServiceError.offerNotAvailableError(desc: "This Offer cannot currently be taken.")
                    }
                    guard offerToTake.approvingToTakeState == .completed else {
                        throw OfferServiceError.offerNotAvailableError(desc: "This Offer cannot be taken unless a token transfer is approved.")
                    }
                    guard offerToTake.takingOfferState == .none || offerToTake.takingOfferState == .validating || offerToTake.takingOfferState == .error else {
                        throw OfferServiceError.offerNotAvailableError(desc: "This Offer is already being taken.")
                    }
                    let newSwap = try createNewSwap(
                        offerToTake: offerToTake,
                        takenSwapAmount: takenSwapAmount,
                        makerSettlementMethod: makerSettlementMethod,
                        takerSettlementMethod: takerSettlementMethod,
                        stablecoinInformationRepository: stablecoinInformationRepository,
                        takerKeyPair: takerKeyPair
                    )
                    logger.notice("takeOffer: recreating EthereumTransaction to take \(offerToTake.id.uuidString) to ensure offerTakingTransaction was created with the contents of offerToTake")
                    guard let blockchainService = blockchainService else {
                        throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(offerToTake.id.uuidString)")
                    }
                    blockchainService.createTakeOfferTransaction(offerID: offerToTake.id, swapStruct: newSwap.toSwapStruct()).map { ($0, newSwap) }.pipe(to: seal.resolve)
                } catch {
                    seal.reject(error)
                }
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] recreatedTransaction, swap -> Promise<(BlockchainTransaction, Swap)> in
                guard var offerTakingTransaction = offerTakingTransaction else {
                    throw OfferServiceError.unexpectedNilError(desc: "Transaction was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                guard recreatedTransaction.data == offerTakingTransaction.data else {
                    throw OfferServiceError.nonmatchingDataError(desc: "Data of offerTakingTransaction did not match that of transaction created with offer \(offerToTake.id.uuidString)")
                }
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                guard let takerKeyPair = takerKeyPair else {
                    throw OfferServiceError.unexpectedNilError(desc: "takerKeyPair was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                logger.notice("takeOffer: persistently storing key pair \(takerKeyPair.interfaceId.base64EncodedString()) for \(swap.id.uuidString)")
                try keyManagerService.storeKeyPair(keyPair: takerKeyPair)
                logger.notice("takeOffer: persistently storing swap \(swap.id.uuidString)")
                let swapForDatabase = DatabaseSwap(
                    id: swap.id.asData().base64EncodedString(),
                    isCreated: swap.isCreated,
                    requiresFill: swap.requiresFill,
                    maker: swap.maker.addressData.toHexString(),
                    makerInterfaceID: swap.makerInterfaceID.base64EncodedString(),
                    taker: swap.taker.addressData.toHexString(),
                    takerInterfaceID: swap.takerInterfaceID.base64EncodedString(),
                    stablecoin: swap.stablecoin.addressData.toHexString(),
                    amountLowerBound: String(swap.amountLowerBound),
                    amountUpperBound: String(swap.amountUpperBound),
                    securityDepositAmount: String(swap.securityDepositAmount),
                    takenSwapAmount: String(swap.takenSwapAmount),
                    serviceFeeAmount: String(swap.serviceFeeAmount),
                    serviceFeeRate: String(swap.serviceFeeRate),
                    onChainDirection: String(swap.onChainDirection),
                    onChainSettlementMethod: swap.onChainSettlementMethod.base64EncodedString(),
                    makerPrivateSettlementMethodData: nil,
                    takerPrivateSettlementMethodData: swap.takerPrivateSettlementMethodData,
                    protocolVersion: String(swap.protocolVersion),
                    isPaymentSent: swap.isPaymentSent,
                    isPaymentReceived: swap.isPaymentReceived,
                    hasBuyerClosed: swap.hasBuyerClosed,
                    hasSellerClosed: swap.hasSellerClosed,
                    onChainDisputeRaiser: String(swap.onChainDisputeRaiser),
                    chainID: String(swap.chainID),
                    state: swap.state.asString,
                    role: swap.role.asString,
                    reportPaymentSentState: swap.reportingPaymentSentState.asString,
                    reportPaymentSentTransactionHash: nil,
                    reportPaymentSentTransactionCreationTime: nil,
                    reportPaymentSentTransactionCreationBlockNumber: nil,
                    reportPaymentReceivedState: swap.reportingPaymentReceivedState.asString,
                    reportPaymentReceivedTransactionHash: nil,
                    reportPaymentReceivedTransactionCreationTime: nil,
                    reportPaymentReceivedTransactionCreationBlockNumber: nil,
                    closeSwapState: swap.closingSwapState.asString,
                    closeSwapTransactionHash: nil,
                    closeSwapTransactionCreationTime: nil,
                    closeSwapTransactionCreationBlockNumber: nil
                )
                try databaseService.storeSwap(swap: swapForDatabase)
                logger.notice("takeOffer: signing transaction for \(offerToTake.id.uuidString)")
                try blockchainService.signTransaction(&offerTakingTransaction)
                let blockchainTransactionForOfferTaking = try BlockchainTransaction(transaction: offerTakingTransaction, latestBlockNumberAtCreation: blockchainService.newestBlockNum, type: .takeOffer)
                let dateString = DateFormatter.createDateString(blockchainTransactionForOfferTaking.timeOfCreation)
                logger.notice("takeOffer: persistently storing taking offer data for \(offerToTake.id.uuidString), including tx hash \(blockchainTransactionForOfferTaking.transactionHash)")
                try databaseService.updateTakingOfferData(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID), transactionHash: blockchainTransactionForOfferTaking.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(blockchainTransactionForOfferTaking.latestBlockNumberAtCreation))
                logger.notice("takeOffer: persistently updating takingOfferState for \(offerToTake.id.uuidString) to \(TakingOfferState.sendingTransaction.asString)")
                try databaseService.updateTakingOfferState(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID), state: TakingOfferState.sendingTransaction.asString)
                logger.notice("takeOffer: updating takingOfferState to sending transaction, storing tx \(blockchainTransactionForOfferTaking.transactionHash) in offer \(offerToTake.id.uuidString), and storing swap in swapTruthSource")
                return Promise.value((blockchainTransactionForOfferTaking, swap))
            }.get(on: DispatchQueue.main) { blockchainTransactionForOfferTaking, swap in
                offerToTake.takingOfferTransaction = blockchainTransactionForOfferTaking
                offerToTake.takingOfferState = .sendingTransaction
                guard var swapTruthSource = self.swapTruthSource else {
                    throw OfferServiceError.unexpectedNilError(desc: "swapTruthSource was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                swapTruthSource.swaps[swap.id] = swap
            }.then(on: DispatchQueue.global(qos: .userInitiated)) { [self] offerTakingBlockchainTransaction, swap -> Promise<(TransactionSendingResult, Swap)> in
                logger.notice("takeOffer: sending \(offerTakingBlockchainTransaction.transactionHash) for \(offerToTake.id.uuidString)")
                guard let blockchainService = blockchainService else {
                    throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during takeOffer call for \(offerToTake.id.uuidString)")
                }
                return blockchainService.sendTransaction(offerTakingBlockchainTransaction).map { ($0, swap) }
            }.get(on: DispatchQueue.global(qos: .userInitiated)) { [self] _, swap in
                logger.notice("takeOffer: persistently updating state of swap \(swap.id.uuidString) to \(SwapState.takeOfferTransactionSent.asString)")
                try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.takeOfferTransactionSent.asString)
                logger.notice("takeOffer: persistently updating takingOfferState of \(offerToTake.id.uuidString) to \(TakingOfferState.awaitingTransactionConfirmation.asString)")
                try databaseService.updateTakingOfferState(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID), state: TakingOfferState.awaitingTransactionConfirmation.asString)
                logger.notice("taheOffer: updating state of swap \(swap.id.uuidString) to \(SwapState.takeOfferTransactionSent.asString) and takingOfferState of offer to \(TakingOfferState.awaitingTransactionConfirmation.asString)")
            }.get(on: DispatchQueue.main) { _, swap in
                swap.state = .takeOfferTransactionSent
                offerToTake.takingOfferState = .awaitingTransactionConfirmation
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _ in
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { [self] error in
                logger.error("takeOffer: encountered error while taking \(offerToTake.id.uuidString), setting takingOfferState to error: \(error.localizedDescription)")
                // It's OK that we don't handle database errors here, because if such an error occurs and the taking offer state isn't updated to error, then when the app restarts, we will check the offer taking transaction, and then discover and handle the error then.
                do {
                    try databaseService.updateTakingOfferState(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID), state: TakingOfferState.error.asString)
                } catch {}
                offerToTake.takingOfferError = error
                DispatchQueue.main.async {
                    offerToTake.takingOfferState = .error
                }
                seal.reject(error)
            }
        }
    }
    
    /**
     Creates a new `Swap` using the supplied data.
     
     This ensures that an offer with an ID equal to `offerToTake` exists on chain and is not taken. Then this calls `validateNewSwapData`, and uses the resulting `ValidatedNewSwapData` to create a new `Swap` along with the information contained in `offerToTake` and the supplied `takerKeyPair`. Then this returns said `Swap`.
     
     - Parameters:
        - offerToTake: The offer that will be taken, for which this is creating a `Swap`.
        - takenSwapAmount: The `Decimal` amount of stablecoin that the user wants to buy/sell. If the offer has lower and upper bound amounts that ARE equal, this parameter will be ignored.
        - makerSettlementMethod: The `SettlementMethod`, belonging to the maker, that the user/taker has selected to send/receive traditional currency payment.
        - takerSettlementMethod: The `SettlementMethod`, belonging to the user/taker, that the user has selected to send/receive traditional currency payment. This must contain the user's valid private settlement method data, and must have method and currency fields matching `makerSettlementMethod`.
        - stablecoinInformationRepository: A `StablecoinInformationRepository` containing information for the stablecoin address-chain ID pair specified by `offerToTake`.
     
     - Returns: A `Swap` created from the supplied data.
     
     - Throws: An `OfferServiceError.unexpectedNilError` if `blockchainService` is `nil`, if no offer with the ID specified in `offerToTake` is found on-chain, if this is unable to find the selected settlement method in the list of settlement methods accepted by the maker, if the taker's address (within `blockchainService`) is `nil` or if `takerKeyPair` is `nil`, or an `OfferServiceError.offerNotAvailableError` if the offer on chain is not created or is already taken.
     */
    func createNewSwap(
        offerToTake: Offer,
        takenSwapAmount: Decimal,
        makerSettlementMethod: SettlementMethod?,
        takerSettlementMethod: SettlementMethod?,
        stablecoinInformationRepository: StablecoinInformationRepository,
        takerKeyPair: KeyPair?
    ) throws -> Swap {
        logger.notice("createNewSwap: checking that \(offerToTake.id.uuidString) is created and not taken")
        guard let blockchainService = blockchainService else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during createNewSwap call for \(offerToTake.id.uuidString)")
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
        logger.notice("createNewSwap: validating data for \(offerToTake.id)")
        let validatedSwapData = try validateNewSwapData(
            offer: offerToTake,
            takenSwapAmount: takenSwapAmount,
            selectedMakerSettlementMethod: makerSettlementMethod,
            selectedTakerSettlementMethod: takerSettlementMethod,
            stablecoinInformationRepository: stablecoinInformationRepository
        )
        logger.notice("createNewSwap: creating new Swap object for \(offerToTake.id.uuidString)")
        var requiresFill: Bool {
            switch(offerToTake.direction) {
            case .buy:
                return false
            case .sell:
                return true
            }
        }
        let serviceFeeAmount = (validatedSwapData.takenSwapAmount * offerToTake.serviceFeeRate) / BigUInt(10_000)
        /*
         We can't simply use the SettlementMethod object in the swapData, because CommutoSwap doesn't allow us to take the offer unless the serialized settlement method data that we use in the takeOffer call exactly matches the serialized settlement method data supplied by the offer maker, and SettlementMethod objects aren't serialized the same way on every platform. Therefore we must find and use the serialized settlement method data supplied by the offer maker in offerToTake.
         */
        guard let selectedOnChainSettlementMethod = (offerToTake.onChainSettlementMethods.first { onChainSettlementMethod in
            do {
                let settlementMethod = try JSONDecoder().decode(SettlementMethod.self, from: onChainSettlementMethod)
                if settlementMethod.currency == validatedSwapData.makerSettlementMethod.currency && settlementMethod.price == validatedSwapData.makerSettlementMethod.price && settlementMethod.method == validatedSwapData.makerSettlementMethod.method {
                    return true
                } else {
                    return false
                }
            } catch {
                logger.warning("createNewSwap: got exception while deserializing settlement method \(onChainSettlementMethod.base64EncodedString()) for \(offerToTake.id.uuidString): \(error.localizedDescription)")
                return false
            }
        }) else {
            throw OfferServiceError.unexpectedNilError(desc: "Unable to find specified settlement method in list of settlement methods accepted by offer maker")
        }
        var swapRole: SwapRole {
            switch offerToTake.direction {
            case .buy:
                // The maker is offering to buy, so we are selling
                return SwapRole.takerAndSeller
            case .sell:
                // The maker is offering to sell, so we are buying
                return SwapRole.takerAndBuyer
            }
        }
        guard let takerAddress = blockchainService.ethKeyStore.getAddress() else {
            throw OfferServiceError.unexpectedNilError(desc: "Unexpectedly got nil while getting taker's address in call for \(offerToTake.id.uuidString)")
        }
        guard let takerKeyPair = takerKeyPair else {
            throw OfferServiceError.unexpectedNilError(desc: "Taker's key pair was nil in call for \(offerToTake.id.uuidString)")
        }

        let newSwap = try Swap(
            isCreated: true,
            requiresFill: requiresFill,
            id: offerToTake.id,
            maker: offerToTake.maker,
            makerInterfaceID: offerToTake.interfaceId,
            taker: takerAddress,
            takerInterfaceID: takerKeyPair.interfaceId,
            stablecoin: offerToTake.stablecoin,
            amountLowerBound: offerToTake.amountLowerBound,
            amountUpperBound: offerToTake.amountUpperBound,
            securityDepositAmount: offerToTake.securityDepositAmount,
            takenSwapAmount: validatedSwapData.takenSwapAmount,
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
            state: .taking,
            role: swapRole
        )
        newSwap.takerPrivateSettlementMethodData = validatedSwapData.takerSettlementMethod.privateData
        return newSwap
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
                                if settlementMethod.currency == swapData.makerSettlementMethod.currency && settlementMethod.price == swapData.makerSettlementMethod.price && settlementMethod.method == swapData.makerSettlementMethod.method {
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
                        var swapRole: SwapRole {
                            switch offerToTake.direction {
                            case .buy:
                                // The maker is offering to buy, so we are selling
                                return SwapRole.takerAndSeller
                            case .sell:
                                // The maker is offering to sell, so we are buying
                                return SwapRole.takerAndBuyer
                            }
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
                            state: .taking,
                            role: swapRole
                        )
                        newSwap.takerPrivateSettlementMethodData = swapData.takerSettlementMethod.privateData
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
                #warning("TODO: get actual taker private data here")
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
                    makerPrivateSettlementMethodData: nil,
                    takerPrivateSettlementMethodData: newSwap.takerPrivateSettlementMethodData,
                    protocolVersion: String(newSwap.protocolVersion),
                    isPaymentSent: newSwap.isPaymentSent,
                    isPaymentReceived: newSwap.isPaymentReceived,
                    hasBuyerClosed: newSwap.hasBuyerClosed,
                    hasSellerClosed: newSwap.hasSellerClosed,
                    onChainDisputeRaiser: String(newSwap.onChainDisputeRaiser),
                    chainID: String(newSwap.chainID),
                    state: newSwap.state.asString,
                    role: newSwap.role.asString,
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
                // The swap is not currently being used by any views, so the state need not be updated on the main DispatchQueue
                //newSwap.state = .takeOfferTransactionBroadcast
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
                logger.notice("takeOffer: removing offer \(offerToTake.id.uuidString) and its settlement methods from persistent storage")
                try databaseService.deleteOffers(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID))
                try databaseService.deleteOfferSettlementMethods(offerID: offerToTake.id.asData().base64EncodedString(), _chainID: String(offerToTake.chainID))
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("takeOffer: encountered error during call for \(offerToTake.id.uuidString): \(error.localizedDescription)")
                seal.reject(error)
            }
        }
    }
    
    /**
     The function called by `BlockchainService` in order to notify `OfferService` that a monitored offer-related `BlockchainTransaction` has failed (either has been confirmed and failed, or has been dropped.)
     
     If `transaction` is of type `BlockchainTransactionType.approveTokenTransferToOpenOffer`, then this finds the offer with the corresponding approving to open transaction hash, persistently updates the state of the offer to `OfferState.transferApprovalFailed`, persistently updates the offer's approve to open state to `TokenTransferApprovalState.error` and on the main `DispatchQueue` sets the `Offer.state` property to `OfferState.transferApprovalFailed`, the `Offer.approvingToOpenError` property to `error`, and the `Offer.approvingToOpenState` property to `TokenTransferApprovalState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.openOffer`, then this finds the offer with the corresponding offer opening transaction hash, persistently updates its state to `OfferState.awaitingOpening`, persistently updates its opening offer state to `OpeningOfferState.error` and on the main `DispatchQueue` sets the `Offer.state` property to `OfferState.awaitingOpening`, the `Offer.openingOfferError` property to `error`, and the `Offer.openingOfferState` to `OpeningOfferState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.cancelOffer`, then this finds the offer with the corresponding cancellation transaction hash, persistently updates its canceling offer state to `CancelingOfferState.error` and on the main `DispatchQueue` sets its `Offer.cancelingOfferError` property to `error` and updates its `Offer.cancelingOfferState` property to `CancelingOfferState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.editOffer`, then this finds the offer with the corresponding editing transaction hash, persistently updates its editing offer state to `EditingOfferState.error` and on the main `DispatchQueue` clears its list of selected settlement methods, sets its `Offer.editingOfferError` property to `error`, and updates its `Offer.editingOfferState` property to `EditingOfferState.error`. Then this deletes the offer's pending settlement methods from persistent storage.
     
     If `transaction` is of type `BlockchainTransactionType.approveTokenTransferToTakeOffer`, then this finds the offer with the corresponding approving to take transaction hash, persistently updates the offer's approve to take state to `TokenTransferApprovalState.error` and on the main `DispatchQueue` sets the `Offer.approvingToTakeError` property to `error` and the `Offer.approvingToTakeState` property to `TokenTransferApprovalState.error`.
     
     If `transaction` is of type `BlockchainTransactionType.takeOffer`, then this finds the offer with the corresponding offer taking transaction hash, persistently updates its taking offer state to `TakingOfferState.error` and on the main `DispatchQueue` sets its `Offer.takingOfferError` property to `error`, and updates its `Offer.takingOfferState` property to `TakingOfferState.error`. Then this finds the swap with an ID equal to that of said offer, persistently updates its state to `SwapState.takeOfferTransactionFailed` and on the main `DispatchQueue` sets the `Offer.state` property to `SwapState.takeOfferTransactionFailed`.
     
     - Parameters:
        - transaction: The `BlockchainTransaction` wrapping the on-chain transaction that has failed.
        - error: A `BlockchainTransactionError` describing why the on-chain transaction has failed.
     */
    func handleFailedTransaction(_ transaction: BlockchainTransaction, error: BlockchainTransactionError) throws {
        logger.warning("handleFailedTransaction: handling \(transaction.transactionHash) of type \(transaction.type.asString) with error \(error.localizedDescription)")
        guard let offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleFailedTransaction call for \(transaction.transactionHash)")
        }
        switch transaction.type {
        case .approveTokenTransferToOpenOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.approvingToOpenTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with approving to open transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with approving to open transaction \(transaction.transactionHash), updating state to \(OfferState.transferApprovalFailed.asString) and approvingToOpenState to \(TokenTransferApprovalState.error.asString) in persistent storage")
            try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OfferState.transferApprovalFailed.asString)
            try databaseService.updateOfferApproveToOpenState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: TokenTransferApprovalState.error.asString)
            logger.warning("handleFailedTransaction: setting state to \(OfferState.transferApprovalFailed.asString), setting approvingToOpenError and updating approvingToOpenState to \(TokenTransferApprovalState.error.asString) for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.state = OfferState.transferApprovalFailed
                offer.approvingToOpenError = error
                offer.approvingToOpenState = TokenTransferApprovalState.error
            }
        case .openOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.offerOpeningTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with offer opening transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with offer opening transaction \(transaction.transactionHash), updating state to \(OfferState.awaitingOpening.asString) and openingOfferState to \(OpeningOfferState.error.asString) in persistent storage")
            try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OfferState.awaitingOpening.asString)
            try databaseService.updateOpeningOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OpeningOfferState.error.asString)
            logger.warning("handleFailedTransaction: setting state to \(OfferState.awaitingOpening.asString), setting openingOfferError and updating openingOfferState to \(OpeningOfferState.error.asString) for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.state = OfferState.awaitingOpening
                offer.openingOfferError = error
                offer.openingOfferState = OpeningOfferState.error
            }
        case .cancelOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.offerCancellationTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with cancellation transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with cancellation transaction \(transaction.transactionHash), updating cancelingOfferState to error in persistent storage")
            try databaseService.updateCancelingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: CancelingOfferState.error.asString)
            logger.warning("handleFailedTransaction: setting cancelingOfferError and updating cancelingOfferState to error for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.cancelingOfferError = error
                offer.cancelingOfferState = .error
            }
        case .editOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.offerEditingTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with editing transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with editing transaction \(transaction.transactionHash), updating editingOfferState to error in persistent storage")
            try databaseService.updateEditingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: EditingOfferState.error.asString)
            logger.warning("handleFailedTransaction: setting editingOfferError and updating editingOfferState to error for \(offer.id.uuidString) and clearing selected settlement methods")
            DispatchQueue.main.sync {
                offer.selectedSettlementMethods = []
                offer.editingOfferError = error
                offer.editingOfferState = .error
            }
            logger.warning("handleFailedTransaction: deleting pending settlement methods for \(offer.id.uuidString)")
            try databaseService.deletePendingOfferSettlementMethods(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID))
        case .approveTokenTransferToTakeOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.approvingToTakeTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with approving to take transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with approving to take transaction \(transaction.transactionHash), updating approvingToTakeState to error in persistent storage")
            try databaseService.updateOfferApproveToTakeState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: TokenTransferApprovalState.error.asString)
            logger.warning("handleFailedTransaction: setting approvingToTakeError and updating approvingToTakeState to error for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.approvingToTakeError = error
                offer.approvingToTakeState = TokenTransferApprovalState.error
            }
        case .takeOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.takingOfferTransaction?.transactionHash == transaction.transactionHash
            })?.value else {
                logger.warning("handleFailedTransaction: offer with offer taking transaction \(transaction.transactionHash) not found in offerTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found offer \(offer.id.uuidString) on \(offer.chainID) with offer taking transaction \(transaction.transactionHash), updating takingOfferState to \(TakingOfferState.error.asString) in persistent storage")
            try databaseService.updateTakingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: TakingOfferState.error.asString)
            logger.warning("handleFailedTransaction: setting takingOfferError and updating takingOfferState to \(TakingOfferState.error.asString) for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.takingOfferError = error
                offer.takingOfferState = TakingOfferState.error
            }
            logger.warning("handleFailedTransaction: searching for swap \(offer.id.uuidString)")
            guard let swapTruthSource = swapTruthSource else {
                throw OfferServiceError.unexpectedNilError(desc: "swapTruthSource was nil during handleFailedTransaction call for takeOffer tx \(transaction.transactionHash)")
            }
            guard let swap = swapTruthSource.swaps.first(where: { id, swap in
                swap.id == offer.id && swap.chainID == offer.chainID
            })?.value else {
                logger.warning("handleFailedTransaction: swap with id \(offer.id.uuidString) not found in swapTruthSource")
                return
            }
            logger.warning("handleFailedTransaction: found swap \(swap.id.uuidString) on \(swap.chainID), updating state to \(SwapState.takeOfferTransactionFailed.asString)")
            try databaseService.updateSwapState(swapID: swap.id.asData().base64EncodedString(), chainID: String(swap.chainID), state: SwapState.takeOfferTransactionFailed.asString)
            logger.warning("handleFailedTransaction: updating state to \(SwapState.takeOfferTransactionFailed.asString) for swap \(swap.id.uuidString)")
            DispatchQueue.main.sync {
                swap.state = SwapState.takeOfferTransactionFailed
            }
        case .reportPaymentSent, .reportPaymentReceived, .closeSwap:
            throw OfferServiceError.invalidValueError(desc: "handleFailedTransaction: received a swap-related transaction \(transaction.transactionHash)")
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `ApprovalEvent`.
     
     If the purpose of `ApprovalEvent` is `TokenTransferApprovalPurpose.openOffer`, this gets the offer with the corresponding approving to open transaction hash, persistently updates its state to `OfferState.awaitingOpening`, persistently updates its approving to open state to `TokenTransferApprovalState.completed`, and then on the main `DispatchQueue` sets its `Offer.state` property to `OfferState.awaitingOpening` and its `Offer.approvingToOpenState` to `TokenTransferApprovalState.completed`.
     
     If the purpose of `ApprovalEvent` is `TokenTransferApprovalPurpose.takeOffer`, this gets the offer with the corresponding approving to take transaction hash, persistently updates its approving to take state to `TokenTransferApprovalState.completed`, and then on the main `DispatchQueue` sets its `Offer.approvingToTakeState` to `TokenTransferApprovalState.completed`.
     
     - Parameter event: The `ApprovalEvent` of which `OfferService` is being notified.
     
     - THrows: `OfferServiceError.unexpectedNilError` if `offerTruthSource` is `nil`.
     */
    func handleTokenTransferApprovalEvent(_ event: ApprovalEvent) throws {
        logger.notice("handleTokenTransferApprovalEvent: handling event with tx hash \(event.transactionHash) and purpose \(event.purpose.asString)")
        guard let offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleTokenTransferApprovalEvent call")
        }
        switch event.purpose {
        case .openOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.approvingToOpenTransaction?.transactionHash == event.transactionHash
            })?.value else {
                logger.warning("handleTokenTransferApprovalEvent: offer with approving to open transaction \(event.transactionHash) not found in offerTruthSource")
                return
            }
            logger.notice("handleTokenTransferApprovalEvent: found offer \(offer.id.uuidString) with approvingToOpen tx hash \(event.transactionHash), persistently updating state to \(OfferState.awaitingOpening.asString) and approvingToOpenState to \(TokenTransferApprovalState.completed.asString)")
            try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OfferState.awaitingOpening.asString)
            try databaseService.updateOfferApproveToOpenState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: TokenTransferApprovalState.completed.asString)
            logger.notice("handleTokenTransferApprovalEvent: updating state to \(OfferState.awaitingOpening.asString) and approvingToOpenState to \(TokenTransferApprovalState.completed.asString) for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.state = .awaitingOpening
                offer.approvingToOpenState = .completed
            }
        case .takeOffer:
            guard let offer = offerTruthSource.offers.first(where: { id, offer in
                offer.approvingToTakeTransaction?.transactionHash == event.transactionHash
            })?.value else {
                logger.warning("handleTokenTransferApprovalEvent: offer with approving to take transaction \(event.transactionHash) not found in offerTruthSource")
                return
            }
            logger.notice("handleTokenTransferApprovalEvent: found offer \(offer.id.uuidString) with approvingToTake tx hash \(event.transactionHash), persistently updating approvingToTakeState to completed")
            try databaseService.updateOfferApproveToTakeState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: TokenTransferApprovalState.completed.asString)
            logger.notice("handleTokenTransferApprovalEvent: updating approvingToTakeState to completed for \(offer.id.uuidString)")
            DispatchQueue.main.sync {
                offer.approvingToTakeState = .completed
            }
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`.
     
     Once notified, `OfferService` saves `event` in `offerOpenedEventsRepository`, gets all on-chain offer data by calling `blockchainService`'s `BlockchainService.getOffer` method, verifies that the chain ID of the event and the offer data match, and then checks if the offer with the ID and chain ID specified in `event` exists in `offerTruthSource`. If it does and if the user is the maker of said offer, than this gets retrieves the user's/maker's key pair, persistently updates the offer's state to `OfferState.awaitingPublicKeyAnnouncement`, and persistently updates the offer's opening offer state to `OpeningOfferState.completed`. Then, on the main `DispatchQueue`, this sets the `Offer.state` property of the offer to `OfferState.awaitingPublicKeyAnnouncement` and the `Offer.openingOfferState` property to `OpeningOfferState.completed`. Then this announces the user's/maker's public key. Finally, this updates the offer's `Offer.state` to `OfferState.offerOpened`, both persistently and in the `Offer` object. If such an offer does not exist or the user is not the maker, then `OfferService` creates a new `Offer` and list of settlement methods using the on-chain `OfferStruct`, checks if `keyManagerService` has the maker's public key and updates the `Offer`'s `Offer.havePublicKey` and `Offer.state` properties accordingly, persistently stores the new offer and its settlement methods, and then synchronously maps the offer's ID to the new `Offer` in `offerTruthSource`'s `OfferTruthSource.offers` dictionary on the main `DispatchQueue`. Finally, regardless of whether the `Offer` exists in `offerTruthSource` and whether the user is the maker of such an offer, this removes `event` from `offerOpenedEventRepository`.
     
     - Parameter event: The `OfferOpenedEvent` of which `OfferService` is being notified.
     
     - Throws: An `OfferServiceError.unexpectedNilError`if `blockchainService` is `nil`, if `offerTruthSource` is `nil`, if the user is the maker of the offer specified by `event` but the user's/maker's key pair is not found or `p2pService` is `nil`, or an `OfferServiceError.nonmatchingChainIDError` if the chain ID specified in event doesn't match that of the corresponding `OfferStruct` found on-chain
     
     or `OfferServiceError.nonmatchingChainIDError`.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) throws {
        logger.notice("handleOfferOpenedEvent: handling event for offer \(event.id.uuidString)")
        offerOpenedEventRepository.append(event)
        guard let blockchainService = blockchainService else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferOpenedEvent call")
        }
        guard let offerStruct = try blockchainService.getOffer(id: event.id) else {
            logger.notice("handleOfferOpenedEvent: no on-chain offer was found with ID specified in OfferOpenedEvent in handleOfferOpenedEvent call. OfferOpenedEvent.id: \(event.id.uuidString)")
            return
        }
        logger.notice("handleOfferOpenedEvent: got offer \(event.id.uuidString)")
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferOpenedEvent did not match chain ID of OfferStruct in handleOfferOpenedEvent call. OfferOpenedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID) + ", OfferOpenedEvent.id: " + event.id.uuidString)
        }
        guard var offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferOpenedEvent call")
        }
        if let offer = offerTruthSource.offers[event.id], offer.chainID == event.chainID, offer.isUserMaker {
            logger.notice("handleOfferOpenedEvent: offer \(event.id.uuidString) made by the user")
            // The user of this interface is the maker of this offer, so we must announce the public key.
            guard let keyPair = try keyManagerService.getKeyPair(interfaceId: offer.interfaceId) else {
                throw OfferServiceError.unexpectedNilError(desc: "handleOfferOpenedEvent: got nil while getting key pair with interface ID \(offer.interfaceId.base64EncodedString()) for offer \(event.id.uuidString), which was made by the user")
            }
            guard let p2pService = p2pService else {
                throw OfferServiceError.unexpectedNilError(desc: "handleOfferOpenedEvent: p2pService was nil during handleOfferOpenedEvent call")
            }
            logger.notice("handleOfferOpenedEvent: persistently updating state of \(offer.id.uuidString) to \(OfferState.awaitingPublicKeyAnnouncement.asString) and updating openingOfferState to \(OpeningOfferState.completed.asString)")
            try databaseService.updateOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OfferState.awaitingPublicKeyAnnouncement.asString)
            try databaseService.updateOpeningOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OpeningOfferState.completed.asString)
            logger.notice("handleOfferOpenedEvent: updating state of \(offer.id.uuidString) to \(OfferState.awaitingPublicKeyAnnouncement.asString) and openingOfferState to \(OpeningOfferState.completed.asString)")
            DispatchQueue.main.sync {
                offer.state = .awaitingPublicKeyAnnouncement
                offer.openingOfferState = OpeningOfferState.completed
            }
            logger.notice("handleOfferOpenedEvent: announcing public key for \(event.id.uuidString)")
            try p2pService.announcePublicKey(offerID: event.id, keyPair: keyPair)
            logger.notice("handleOfferOpenedEvent: announced public key for \(event.id.uuidString)")
            logger.notice("handleOfferOpenedEvent: persistently updating state of \(offer.id.uuidString) to \(OfferState.offerOpened.asString)")
            try databaseService.updateOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: OfferState.offerOpened.asString)
            logger.notice("updating state of \(offer.id.uuidString) to \(OfferState.offerOpened.asString)")
            DispatchQueue.main.sync {
                offer.state = .offerOpened
            }
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
                logger.warning("Got nil while creating Offer from OfferStruct data during handleOfferOpenedEvent call. OfferOpenedEvent.id: \(event.id.uuidString)")
                offerOpenedEventRepository.remove(event)
                return
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
                state: offer.state.asString,
                approveToOpenState: offer.approvingToOpenState.asString,
                approveToOpenTransactionHash: nil,
                approveToOpenTransactionCreationTime: nil,
                approveToOpenTransactionCreationBlockNumber: nil,
                openingOfferState: offer.openingOfferState.asString,
                openingOfferTransactionHash: nil,
                openingOfferTransactionCreationTime: nil,
                openingOfferTransactionCreationBlockNumber: nil,
                cancelingOfferState: offer.cancelingOfferState.asString,
                offerCancellationTransactionHash: nil,
                offerCancellationTransactionCreationTime: nil,
                offerCancellationTransactionCreationBlockNumber: nil,
                editingOfferState: offer.editingOfferState.asString,
                offerEditingTransactionHash: nil,
                offerEditingTransactionCreationTime: nil,
                offerEditingTransactionCreationBlockNumber: nil,
                approveToTakeState: offer.approvingToTakeState.asString,
                approveToTakeTransactionHash: nil,
                approveToTakeTransactionCreationTime: nil,
                approveToTakeTransactionCreationBlockNumber: nil,
                takingOfferState: offer.takingOfferState.asString,
                takingOfferTransactionHash: nil,
                takingOfferTransactionCreationTime: nil,
                takingOfferTransactionCreationBlockNumber: nil
            )
            logger.notice("handleOfferOpenedEvent: persistently storing \(offer.id.uuidString)")
            try databaseService.storeOffer(offer: offerForDatabase)
            logger.notice("handleOfferOpenedEvent: persistently storing settlement methods for \(offer.id.uuidString)")
            var settlementMethodStrings: [(String, String?)] = []
            for settlementMethod in offer.settlementMethods {
                settlementMethodStrings.append(((settlementMethod.onChainData ?? Data()).base64EncodedString(), nil))
            }
            try databaseService.storeOfferSettlementMethods(offerID: offerForDatabase.id, _chainID: offerForDatabase.chainID, settlementMethods: settlementMethodStrings)
            logger.notice("handleOfferOpenedEvent: adding offer \(offer.id.uuidString) to offerTruthSource")
            DispatchQueue.main.sync {
                offerTruthSource.offers[offer.id] = offer
            }
        }
        offerOpenedEventRepository.remove(event)
    }
    
    #warning("TODO: when we support multiple chains, someone could corrupt the interface's knowledge of settlement methods on Chain A by creating another offer with the same ID on Chain B and then changing the settlement methods of the offer on Chain B. If this interface is listening to both, it will detect the OfferEditedEvent from Chain B and then use the settlement methods from the offer on Chain B to update its local Offer object corresponding to the object from Chain A. We should only update settlement methods if the chainID of the OfferEditedEvent matches that of the already-stored offer")
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferEditedEvent`.
     
     Once notified, `OfferService` saves `event` in `offerEditedEventRepository`, gets updated on-chain offer data by calling `BlockchainService.getOffer`, and verifies that the chain ID of the event and the offer data match. Then this checks if the user of the interface is the maker of the offer being edited. If so, then the new settlement methods for the offer and their associated private data should be stored in the pending settlement methods database table. So this gets that data from `databaseService`, and then deserializes the data to `SettlementMethod` objects and adds them to a list, logging warnings when such a `SettlementMethod` has no associated private data. Then this creates another list of `SettlementMethod` objects that it creates by deserializing the settlement method data in the new on-chain offer data. Then this iterates through the latter list of `SettlementMethod` objects, searching for matching `SettlementMethod` objects in the former list (matching meaning that price, currency, and fiat currency values are equal; obviously on-chain settlement methods will have no private data). If, for a given `SettlementMethod` in the latter list, a matching `SettlementMethod` (which definitely has associated private data) is found in the former list, the matching element in the former list is added to a third list of `SettlementMethod`s. Then this checks whether the corresponding `Offer` has a non-`nil` `Offer.offerEditingTransaction` property. If it does, then this compares the transaction hash of the value of that property to that of `event`. If they match, this sets a flag indicating that these transaction hashes match. If this flag is set, this persistently updates `Offer`s `Offer.editingOfferState` property to `EditingOfferState.COMPLETED`. Then, on the main `DispatchQueue`, if the matching transaction hash flag has been set, this updates the corresponding `Offer`'s `Offer.editingOfferState` to `EditingOfferState.COMPLETED` and clears the `Offer`'s `Offer.selectedSettlementMethods` list. Then, still on the main `DispatchQueue`, regardless of the status of the flag, this sets the corresponding `Offer`'s settlement methods equal to the contents of the third list of new `SettlementMethod`s.
     
     If the user of this interface is not the maker of the offer being edited, this creates a new list of `SettlementMethod`s by deserializing the settlement method data in the new on-chain offer data, persistently stores the list of new `SettlementMethod`s as the offer's settlement methods, and sets the corresponding `Offer`'s settlement methods equal to the contents of this list on the main `DispatchQueue`.
     
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
            logger.notice("handleOfferEditedEvent: no on-chain offer was found with ID specified in OfferEditedEvent in handleOfferEditedEvent call. OfferEditedEvent.id: \(event.id.uuidString)")
            return
        }
        logger.notice("handleOfferEditedEvent: got offer \(event.id.uuidString)")
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferEditedEvent did not match chain ID of OfferStruct in handleOfferEditedEvent call. OfferEditedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID))
        }
        let offerIDB64String = event.id.asData().base64EncodedString()
        let chainIDString = String(event.chainID)
        guard let offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferEditedEvent call")
        }
        /*
         If we are the maker of the offer being edited, then we should have the new settlement methods and their associated private data in the pending settlement methods database table. So we get these
         */
        let offer = offerTruthSource.offers[event.id]
        if let offer = offer, offer.isUserMaker {
            logger.notice("handleOfferEditedEvent: \(event.id.uuidString) was made by interface user")
            /*
             The user of this interface is the maker of this offer, and therefore we should have pending settlement methods for this offer in persistent storage.
             */
            var newSettlementMethods: [SettlementMethod] = []
            let pendingSettlementMethods = try databaseService.getPendingOfferSettlementMethods(offerID: offerIDB64String, _chainID: chainIDString)
            var deserializedPendingSettlementMethods: [SettlementMethod] = []
            if let pendingSettlementMethods = pendingSettlementMethods {
                if pendingSettlementMethods.count != offerStruct.settlementMethods.count {
                    logger.warning("handleOfferEditedEvent: mismatching pending settlement methods counts for \(event.id.uuidString): \(pendingSettlementMethods.count) pending settlement methods in persistent storage, \(offerStruct.settlementMethods.count) settlement methods on-chain")
                }
                for pendingSettlementMethod in pendingSettlementMethods {
                    do {
                        var deserializedPendingSettlementMethod = try JSONDecoder().decode(SettlementMethod.self, from: Data(base64Encoded: pendingSettlementMethod.0) ?? Data())
                        deserializedPendingSettlementMethod.privateData = pendingSettlementMethod.1
                        if deserializedPendingSettlementMethod.privateData == nil {
                            logger.warning("handleOfferEditedEvent: did not find private data for pending settlement method \(pendingSettlementMethod.0) for \(event.id.uuidString)")
                        }
                        deserializedPendingSettlementMethods.append(deserializedPendingSettlementMethod)
                    } catch {
                        logger.warning("handleOfferEditedEvent: encountered error while deserializing pending settlement method \(pendingSettlementMethod.0) for \(event.id.uuidString)")
                    }
                }
            } else {
                logger.warning("handleOfferEditedEvent: found no pending settlement methods for \(event.id.uuidString)")
            }
            
            for onChainSettlementMethod in offerStruct.settlementMethods {
                do {
                    let deserializedOnChainSettlementMethod = try JSONDecoder().decode(SettlementMethod.self, from: onChainSettlementMethod)
                    let correspondingDeserializedPendingSettlementMethod = deserializedPendingSettlementMethods.first { deserializedPendingSettlementMethod in
                        if deserializedOnChainSettlementMethod.currency == deserializedPendingSettlementMethod.currency && deserializedOnChainSettlementMethod.price == deserializedPendingSettlementMethod.price && deserializedOnChainSettlementMethod.method == deserializedPendingSettlementMethod.method {
                            return true
                        } else {
                            return false
                        }
                    }
                    if let correspondingDeserializedPendingSettlementMethod = correspondingDeserializedPendingSettlementMethod {
                        newSettlementMethods.append(correspondingDeserializedPendingSettlementMethod)
                    } else {
                        logger.warning("handleOfferEditedEvent: unable to find pending settlement method for on-chain settlement method \(onChainSettlementMethod) for \(event.id.uuidString)")
                    }
                } catch {
                    logger.warning("handleOfferEditedEvent: encountered error while deserializing on-chain settlement method \(onChainSettlementMethod.base64EncodedString()) for \(event.id.uuidString)")
                }
            }
            
            if newSettlementMethods.count != offerStruct.settlementMethods.count {
                logger.warning("handleOfferEditedEvent: mismatching new settlement methods counts for \(event.id.uuidString): \(newSettlementMethods.count) new settlement methods, \(offerStruct.settlementMethods.count) settlement methods on-chain")
            }
            
            let newSerializedSettlementMethods = try newSettlementMethods.map { newSettlementMethod in
                // Since we just deserialized these settlement methods, we should never get an error while re-serializing them again
                return (try JSONEncoder().encode(newSettlementMethod).base64EncodedString(), newSettlementMethod.privateData)
            }
            try databaseService.storeOfferSettlementMethods(offerID: offerIDB64String, _chainID: chainIDString, settlementMethods: newSerializedSettlementMethods)
            logger.notice("handleOfferEditedEvent: persistently stored \(newSerializedSettlementMethods.count) settlement methods for \(event.id.uuidString)")
            try databaseService.deletePendingOfferSettlementMethods(offerID: offerIDB64String, _chainID: chainIDString)
            logger.notice("handleOfferEditedEvent: removed pending settlement methods from persistent storage for \(event.id.uuidString)")
            var gotExpectedOfferEditingTransaction = false
            if let offerEditingTransaction = offer.offerEditingTransaction {
                if offerEditingTransaction.transactionHash == event.transactionHash {
                    logger.notice("handleOfferEditedEvent: tx hash \(event.transactionHash) of event matches that for offer \(event.id.uuidString): \(offerEditingTransaction.transactionHash)")
                    gotExpectedOfferEditingTransaction = true
                } else {
                    logger.warning("handleOfferEditedEvent: tx hash \(event.transactionHash) does not match that for offer \(event.id.uuidString): \(offerEditingTransaction.transactionHash)")
                }
            } else {
                logger.warning("handleOfferEditedEvent: offer \(event.id.uuidString) made by the interface user has no offer editing transaction")
            }
            if gotExpectedOfferEditingTransaction {
                logger.notice("handleOfferEditedEvent: persistently updating editing offer state of \(event.id.uuidString) to completed")
                try databaseService.updateEditingOfferState(offerID: event.id.asData().base64EncodedString(), _chainID: String(event.chainID), state: EditingOfferState.completed.asString)
            }
            logger.notice("updating offer \(event.id.uuidString) in offerTruthSource")
            try DispatchQueue.main.sync {
                if (gotExpectedOfferEditingTransaction) {
                    offer.editingOfferState = .completed
                    offer.selectedSettlementMethods = []
                }
                try offer.updateSettlementMethods(settlementMethods: newSettlementMethods)
            }
            
        } else {
            logger.notice("handleOfferEditedEvent: \(event.id.uuidString) was not made by interface user")
            var settlementMethodStrings: [(String, String?)] = []
            for settlementMethod in offerStruct.settlementMethods {
                settlementMethodStrings.append((settlementMethod.base64EncodedString(), nil))
            }
            try databaseService.storeOfferSettlementMethods(offerID: offerIDB64String, _chainID: chainIDString, settlementMethods: settlementMethodStrings)
            logger.notice("handleOfferEditedEvent: persistently stored \(settlementMethodStrings.count) settlement methods for \(event.id.uuidString)")
            if let offer = offer {
                DispatchQueue.main.sync {
                    offer.updateSettlementMethodsFromChain(onChainSettlementMethods: offerStruct.settlementMethods)
                }
                logger.notice("handleOfferEditedEvent: updated offer \(event.id.uuidString) in offerTruthSource")
            } else {
                logger.warning("handleOfferEditedEvent: could not find offer \(event.id.uuidString) in offerTruthSource")
            }
        }
        offerEditedEventRepository.remove(event)
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferCanceledEvent`. Once notified, `OfferService` saves `event` in `offerCanceledEventRepository`, and checks for the corresponding `Offer` (with an ID and chain ID matching that specified in `event`) in `offerTruthSource`. If it finds such an `Offer`, it checks whether the offer was made by the user of this interface. If it was, this checks whether the hash of the offer's `Offer.offerCancellationTransaction` equals that of `event`. If they do not match, then this updates the `Offer`, both in `offerTruthSource` and in persistent storage, with a new `BlockchainTransaction` containing the hash specified in `event`. Then, regardless of whether the hashes match, this sets the offer's `Offer.cancelingOfferState` to `CancelingOfferState.completed` on the main Dispatch Queue. Then, regardless of whether the `Offer` was or was not made by the user of this interface, this sets the offer's `Offer.isCreated` flag to `false` and its `Offer.state` to `OfferState.canceled`, and then removes the offer from `offerTruthSource` on the main Dispatch Queue. Finally, regardless of whether an `Offer` was found in `offerTruthSource`, this removes the offer with the ID and chain ID specified in `event` (and its settlement methods) from persistent storage. Finally, this removes `event` from `offerCanceledEventRepository`
     
     - Parameter event: The `OfferCanceledEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) throws {
        logger.notice("handleOfferCanceledEvent: handling event for offer \(event.id.uuidString)")
        let offerIdString = event.id.asData().base64EncodedString()
        offerCanceledEventRepository.append(event)
        logger.notice("handleOfferCanceledEvent: persistently updating state for \(event.id.uuidString)")
        try databaseService.updateOfferState(offerID: offerIdString, _chainID: String(event.chainID), state: OfferState.canceled.asString)
        guard var offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferCanceledEvent call for \(event.id.uuidString)")
        }
        if let offer = offerTruthSource.offers[event.id], offer.chainID == event.chainID {
            logger.notice("handleOfferCanceledEvent: found offer \(event.id.uuidString) in offerTruthSource")
            if offer.isUserMaker {
                var mustUpdateOfferCancellationTransaction = false
                logger.notice("handleOfferCanceledEvent: offer \(event.id.uuidString) made by interface user")
                if let offerCancellationTransaction = offer.offerCancellationTransaction {
                    if offerCancellationTransaction.transactionHash == event.transactionHash {
                        logger.notice("handleOfferCanceledEvent: tx hash \(event.transactionHash) of event matches that for offer \(event.id.uuidString): \(offerCancellationTransaction.transactionHash)")
                    } else {
                        logger.warning("handleOfferCanceledEvent: tx hash \(event.transactionHash) of event does not match that for offer \(event.id.uuidString): \(offerCancellationTransaction.transactionHash), updating with new transaction hash")
                        mustUpdateOfferCancellationTransaction = true
                    }
                } else {
                    logger.warning("handleOfferCanceledEvent: offer \(event.id.uuidString) made by interface user has no offer cancellation transaction, updating with transaction hash")
                    mustUpdateOfferCancellationTransaction = true
                }
                if mustUpdateOfferCancellationTransaction {
                    let offerCancellationTransaction = BlockchainTransaction(transactionHash: event.transactionHash, timeOfCreation: Date(), latestBlockNumberAtCreation: 0, type: .cancelOffer)
                    DispatchQueue.main.sync {
                        offer.offerCancellationTransaction = offerCancellationTransaction
                    }
                    logger.warning("handleOfferCanceledEvent: persistently storing tx hash \(event.transactionHash) for \(event.id.uuidString)")
                    let dateString = DateFormatter.createDateString(offerCancellationTransaction.timeOfCreation)
                    try databaseService.updateOfferCancellationData(offerID: offerIdString, _chainID: String(event.chainID), transactionHash: offerCancellationTransaction.transactionHash, transactionCreationTime: dateString, latestBlockNumberAtCreationTime: Int(offerCancellationTransaction.latestBlockNumberAtCreation))
                }
                logger.notice("handleOfferCanceledEvent: updating cancelingOfferState of user-as-maker offer \(event.id.uuidString) to \(CancelingOfferState.completed.asString)")
                DispatchQueue.main.sync {
                    offer.cancelingOfferState = .completed
                }
            }
            logger.notice("handleOfferCanceledEvent: updating state of \(event.id.uuidString) to \(OfferState.canceled.asString)")
            DispatchQueue.main.sync {
                offer.isCreated = false
                offer.state = .canceled
            }
            logger.notice("handleOfferCanceledEvent: removing \(event.id.uuidString) from offerTruthSource")
            _ = DispatchQueue.main.sync {
                offerTruthSource.offers.removeValue(forKey: event.id)
            }
        }
        logger.notice("handleOfferCanceledEvent: removing \(event.id.uuidString) with chain ID \(event.chainID) from persistent storage")
        try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
        logger.notice("handleOfferCanceledEvent: removing settlement methods for \(event.id.uuidString) with chain ID \(event.chainID) from persistent storage")
        try databaseService.deleteOfferSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
        offerCanceledEventRepository.remove(event)
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferTakenEvent`.
     
     Once notified, `OfferService` saves `event` in `offerTakenEventRepository` and searches for an offer with the ID and chain ID specified in `event`. If such an offer is found, this calls `SwapService.sendTakerInformationMessage`, passing the swap ID and chain ID in `event`. If this call returns true, then the user of this interface is the taker of this offer and necessary action has been taken, so this persistently updates the state of the offer to `OfferState.taken` and the taking offer state of the offer to `TakingOfferState.completed`, and then does the same to the `Offer` object on the main `DispatchQueue` and then returns. Otherwise, this checks if the user of this interface is the maker of the offer. If so, this calls `swapService.handleNewSwap`. Then, regardless of whether the user of this interface is the maker of the offer, this removes the corresponding offer and its settlement methods from persistent storage, and then synchronously removes the `Offer` from `offersTruthSource` on the main `DispatchQueue`. Finally, regardless of whether the user of this interface is the maker or taker of this offer or neither, this removes `event` from `offerTakenEventRepository`.
     
     - Parameter event: The `OfferTakenEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) throws {
        logger.notice("handleOfferTakenEvent: handling event for offer \(event.id.uuidString)")
        let offerIdString = event.id.asData().base64EncodedString()
        offerTakenEventRepository.append(event)
        guard var offerTruthSource = offerTruthSource else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferTakenEvent call")
        }
        guard let offer = offerTruthSource.offers[event.id] else {
            logger.notice("handleOfferTakenEvent: got event for offer \(event.id.uuidString) not found in offerTruthSource")
            offerTakenEventRepository.remove(event)
            return
        }
        if (offer.chainID != event.chainID) {
            logger.warning("handleOfferTakenEvent: chain ID \(String(event.chainID)) did not match chain ID of offer \(event.id.uuidString)")
            return
        }
        // We try to send taker information for the swap with the ID specified in the event. If we cannot (possibly because we are not the taker), sendTakerInformationMessage will NOT send a message and will return false, and we handle other possible cases
        logger.notice("handleOfferTakenEvent: checking role for \(event.id.uuidString)")
        if try swapService.sendTakerInformationMessage(swapID: event.id, chainID: event.chainID) {
            logger.notice("handleOfferTakenEvent: sent taker info for \(event.id.uuidString), persistently updating state of \(offer.id.uuidString) to \(OfferState.taken.asString)")
            try databaseService.updateOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: OfferState.taken.asString)
            logger.notice("handleOfferTakenEvent: persistently updating takingOfferState of \(offer.id.uuidString) to \(TakingOfferState.completed.asString)")
            try databaseService.updateTakingOfferState(offerID: offer.id.asData().base64EncodedString(), _chainID: String(offer.chainID), state: TakingOfferState.completed.asString)
            logger.notice("handleOfferTakenEvent: updating state of \(offer.id.uuidString) to \(OfferState.taken.asString) and takingOfferState to \(TakingOfferState.completed.asString)")
            DispatchQueue.main.sync {
                offer.state = .taken
                offer.takingOfferState = .completed
            }
        } else {
            // If we have the offer and we are the maker, then we handle the new swap
            if offer.isUserMaker {
                logger.notice("handleOfferTakenEvent: \(event.id.uuidString) was made by the user of this interface, handling new swap")
                try swapService.handleNewSwap(takenOffer: offer)
            }
            // Regardless of whether we are or are not the maker of this offer, we are not the taker, so we remove the offer and its settlement methods.
            try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
            logger.notice("handleOfferTakenEvent: deleted offer \(event.id.uuidString) from persistent storage")
            try databaseService.deleteOfferSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
            logger.notice("handleOfferTakenEvent: deleted settlement methods of offer \(event.id.uuidString) from persistent storage")
            DispatchQueue.main.sync {
                offer.isTaken = true
                offerTruthSource.offers.removeValue(forKey: event.id)
            }
            logger.notice("handleOfferTakenEvent: removed offer \(event.id.uuidString) from offerTruthSource if present")
        }
        offerTakenEventRepository.remove(event)
    }
    
    /**
     The function called by `P2PService` to notify `OfferService` of a `PublicKeyAnnouncement`.
     
     Once notified, `OfferService` checks for a key pair in `keyManagerService` with an interface ID equal to that of the public key contained in `message`. If such a key pair is present, then this returns, to avoid storing the user's own public key. Otherwise, if no such key pair exists in `keyManagerService`, this checks that the public key in `message` is not already saved in persistent storage via `keyManagerService`, and does so if it is not. Then this checks `offerTruthSource` for an offer with the ID specified in `message` and an interface ID equal to that of the public key in `message`. If it finds such an offer, it checks the offer's `havePublicKey` and `state` properties. If `havePublicKey` is true or `state` is at or beyond `offerOpened`, then it returns because this interface already has the public key for this offer. Otherwise, it updates the offer's `havePublicKey` property to true, to indicate that we have the public key necessary to take the offer and communicate with its maker, and if the offer has not already passed through the `offerOpened` state, updates its `state` property to `offerOpened`. It updates these properties in persistent storage as well.
     
     - Parameter message: The `PublicKeyAnnouncement` of which `OfferService` is being notified.
     */
    func handlePublicKeyAnnouncement(_ message: PublicKeyAnnouncement) throws {
        logger.notice("handlePublicKeyAnnouncement: handling announcement for offer \(message.offerId.uuidString)")
        if try keyManagerService.getKeyPair(interfaceId: message.publicKey.interfaceId) != nil {
            logger.notice("handlePublicKeyAnnouncement: detected announcement for \(message.offerId.uuidString) made by the user of this interface")
            return
        }
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
         If we already have the public key for an offer and/or that offer is at or beyond the offerOpened state, then we do nothing.
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

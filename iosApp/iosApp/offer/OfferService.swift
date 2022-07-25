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
class OfferService<_OfferTruthSource>: OfferNotifiable, OfferMessageNotifiable where _OfferTruthSource: OfferTruthSource {
    
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
     The `BlockchainService` that this uses for interacting with the blockchain.
     */
    var blockchainService: BlockchainService? = nil
    
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
     
     On the global `DispatchQueue`, this creates and persistently stores a new key pair, creates a new offer ID and a new `Offer` from the information contained in `offerData`. Then, still on the global `DispatchQueue`, this persistently stores the new `Offer`,  approves token transfer to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract, and then calls the CommutoSwap contract's [openOffer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#open-offer) function, passing the new offer ID and `Offer`. Then, on the main `DispatchQueue`, the new `Offer` is added to `offerTruthSource`.
     
     - Parameters:
        - offerData: A `ValidatedNewOfferData` containing the data for the new offer to be opened.
        - afterObjectCreation: A closure that will be executed after the new key pair, offer ID and `Offer` object are created.
        - afterPersistentStorage: A closure that will be executed after the `Offer` is persistently stored.
        - afterTransferApproval: A closure that will be run after the token transfer approval to the [CommutoSwap](https://github.com/jimmyneutront/commuto-protocol/blob/main/CommutoSwap.sol) contract is completed.
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
                        #warning("TODO: get proper chain ID here")
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
                            havePublicKey: true
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
                do {
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
                        havePublicKey: newOffer.havePublicKey
                    )
                    try databaseService.storeOffer(offer: newOfferForDatabase)
                    if let afterPersistentStorage = afterPersistentStorage {
                        afterPersistentStorage()
                    }
                } catch {
                    throw error
                }
                logger.notice("openOffer: adding \(newOffer.id.uuidString) to offerTruthSource")
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
            }.get(on: DispatchQueue.main) { [self] _, newOffer in
                guard offerTruthSource != nil else {
                    throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during openOffer call")
                }
                offerTruthSource!.offers[newOffer.id] = newOffer
            }.done(on: DispatchQueue.global(qos: .userInitiated)) { _, newOffer in
                self.logger.notice("openOffer: opened \(newOffer.id.uuidString)")
                if let afterOpen = afterOpen {
                    afterOpen()
                }
                seal.fulfill(())
            }.catch(on: DispatchQueue.global(qos: .userInitiated)) { error in
                self.logger.error("offerOpened: encountered error: \(error.localizedDescription)")
                seal.reject(error)
            }
            
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`. Once notified, `OfferService` saves `event` in `offerOpenedEventsRepository`, gets all on-chain offer data by calling `blockchainServices's` `getOffer` method, verifies that the chain ID of the event and the offer data match, creates a new `Offer` with the results, checks if `keyManagerService` has the maker's public key and updates the `Offer`'s `havePublicKey` property accordingly, persistently stores the new offer and its settlement methods, removes `event` from `offerOpenedEventsRepository`, and then synchronously maps the offer's ID to the new `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
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
        let havePublicKey = (try keyManagerService.getPublicKey(interfaceId: offerStruct.interfaceId) != nil)
        logger.notice("handleOfferOpenedEvent: havePublicKey for offer \(event.id.uuidString): \(havePublicKey)")
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
            havePublicKey: havePublicKey
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
            havePublicKey: offer.havePublicKey
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
    
    #warning("TODO: when we support multiple chains, someone could corrupt the interface's knowledge of settlement methods on Chain A by creating another offer with the same ID on Chain B and then changing the settlement methods of the offer on Chain B. If this interface is listening to both, it will detect the OfferEditedEvent from Chain B and then use the settlement methods from the offer on Chain B to update its local Offer object corresponding to the object from Chain A. We should only update settlement methods if the chainID of the OfferEditedEvent matches that of the already-stored offer")
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferEditedEvent`. Once notified, `OfferService` saves `event` in `offerEditedEventsRepository`, gets updated on-chain offer data by calling `blockchainService`'s `getOffer` method, verifies that the chain ID of the event and the offer data match, creates an updated `Offer` with the results, checks if `keyManagerService` has the maker's public key and updates the `havePublicKey` property of the `Offer` and the persistently stored offer accordingly, updates the settlement methods of the corresponding persistently stored offer, removes `event` from `offerEditedEventsRepository`, and then synchronously maps the offer's ID to the updated `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
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
        let havePublicKey = (try keyManagerService.getPublicKey(interfaceId: offerStruct.interfaceId) != nil)
        logger.notice("handleOfferEditedEvent: havePublicKey for offer \(event.id.uuidString): \(havePublicKey)")
        guard let offer = Offer(
            isCreated: offerStruct.isCreated,
            isTaken: offerStruct.isTaken,
            id: event.id,
            maker: offerStruct.maker,
            interfaceId: offerStruct.interfaceId,
            stablecoin: offerStruct.stablecoin,
            amountLowerBound: offerStruct.amountLowerBound,
            amountUpperBound: offerStruct.amountUpperBound,
            securityDepositAmount: offerStruct.securityDepositAmount,
            serviceFeeRate: offerStruct.serviceFeeRate,
            onChainDirection: offerStruct.direction,
            onChainSettlementMethods: offerStruct.settlementMethods,
            protocolVersion: offerStruct.protocolVersion,
            chainID: offerStruct.chainID,
            havePublicKey: havePublicKey
        ) else {
            throw OfferServiceError.unexpectedNilError(desc: "Got nil while creating Offer from OfferStruct data during handleOfferEditedEvent call. OfferEditedEvent.id: " + event.id.uuidString)
        }
        let offerIdString = offer.id.asData().base64EncodedString()
        let chainIDString = String(offer.chainID)
        try databaseService.updateOfferHavePublicKey(offerID: offerIdString, _chainID: chainIDString, _havePublicKey: offer.havePublicKey)
        logger.notice("handleOfferEditedEvent: persistently updated havePublicKey for offer \(offer.id.uuidString)")
        var settlementMethodStrings: [String] = []
        for settlementMethod in offerStruct.settlementMethods {
            settlementMethodStrings.append(settlementMethod.base64EncodedString())
        }
        try databaseService.storeSettlementMethods(offerID: offerIdString, _chainID: chainIDString, settlementMethods: settlementMethodStrings)
        logger.notice("handleOfferEditedEvent: persistently stored \(settlementMethodStrings.count) settlement methods for offer \(offer.id.uuidString)")
        offerEditedEventRepository.remove(event)
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferEditedEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            offerTruthSource!.offers[offer.id] = offer
        }
        logger.notice("handleOfferEditedEvent: added updated offer \(offer.id.uuidString) to offerTruthSource")
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
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferCanceledEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            if offerTruthSource!.offers[event.id]?.chainID == event.chainID {
                offerTruthSource!.offers.removeValue(forKey: event.id)
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
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferTakenEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            if offerTruthSource!.offers[event.id]?.chainID == event.chainID {
                offerTruthSource!.offers.removeValue(forKey: event.id)
            }
        }
        logger.notice("handleOfferTakenEvent: removed offer \(event.id.uuidString) from offerTruthSource if present")
    }
    
    /**
     The function called by `P2PService` to notify `OfferService` of a `PublicKeyAnnouncement`. Once notified, `OfferService` checks that the public key in `message` is not already saved in persistent storage via `keyManagerService`, and does so if it is not. Then this checks `offerTruthSource` for an offer with the ID specified in `message` and an interface ID equal to that of the public key in `message`. If it finds such an offer, it updates the offer's `havePublicKey` property to true, to indicate that we have the public key necessary to take the offer and communicate with its maker.
     
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
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handlePublicKeyAnnouncement call")
        }
        guard let offer = DispatchQueue.main.sync(execute: {
            offerTruthSource!.offers[message.offerId]
        }) else {
            logger.notice("handlePublicKeyAnnouncement: got announcement for offer not in offerTruthSource: \(message.offerId.uuidString)")
            return
        }
        if offer.interfaceId == message.publicKey.interfaceId {
            DispatchQueue.main.sync {
                offerTruthSource!.offers[message.offerId]?.havePublicKey = true
            }
            logger.notice("handlePublicKeyAnnouncement: set havePublicKey true for offer \(message.offerId.uuidString)")
            let offerIDString = message.offerId.asData().base64EncodedString()
            let chainIDString = String(offer.chainID)
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

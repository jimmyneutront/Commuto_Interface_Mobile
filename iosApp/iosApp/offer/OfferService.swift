//
//  OfferService.swift
//  iosApp
//
//  Created by jimmyt on 6/1/22.
//  Copyright © 2022 orgName. All rights reserved.
//

import Foundation
import PromiseKit
import web3swift

/**
 The main Offer Service. It is responsible for processing and organizing offer-related data that it receives from `BlockchainService` and `P2PService` in order to maintain an accurate list of all open offers in `OffersViewModel`.
 */
class OfferService<_OfferTruthSource>: OfferNotifiable where _OfferTruthSource: OfferTruthSource {
    
    /**
     Initializes a new OfferService object.
     
     - Parameters:
        - databaseService: The `DatabaseService` that the `OfferService` will use for persistent storage.
        - offerOpenedEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferOpenedEvent`s during `handleOfferOpenedEvent` calls.
        - offerCanceledEventRepository: The `BlockchainEventRepository` that the `OfferService` will use to store `OfferCanceledEvent`s during `handleOfferCanceledEvent` calls.
     */
    init(
        databaseService: DatabaseService,
        offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent> = BlockchainEventRepository<OfferOpenedEvent>(),
        offerEditedEventRepository: BlockchainEventRepository<OfferEditedEvent> = BlockchainEventRepository<OfferEditedEvent>(),
        offerCanceledEventRepository: BlockchainEventRepository<OfferCanceledEvent> = BlockchainEventRepository<OfferCanceledEvent>(),
        offerTakenEventRepository: BlockchainEventRepository<OfferTakenEvent> = BlockchainEventRepository<OfferTakenEvent>()
    ) {
        self.databaseService = databaseService
        self.offerOpenedEventRepository = offerOpenedEventRepository
        self.offerEditedEventRepository = offerEditedEventRepository
        self.offerCanceledEventRepository = offerCanceledEventRepository
        self.offerTakenEventRepository = offerTakenEventRepository
    }
    
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
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`. Once notified, `OfferService` saves `event` in `offerOpenedEventsRepository`, gets all on-chain offer data by calling `blockchainServices's` `getOffer` method, verifies that the chain ID of the event and the offer data match, creates a new `Offer` with the results, persistently stores the new offer and its settlement methods, removes `event` from `offerOpenedEventsRepository`, and then synchronously maps the offer's ID to the new `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferOpenedEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError` or `OfferServiceError.nonmatchingChainIDError`.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) throws {
        offerOpenedEventRepository.append(event)
        guard blockchainService != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferOpenedEvent call")
        }
        // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
        guard let offerStruct = try blockchainService!.getOffer(id: event.id) else {
            throw OfferServiceError.unexpectedNilError(desc: "No on-chain offer was found with ID specified in OfferOpenedEvent in handleOfferOpenedEvent call. OfferOpenedEvent.id: " + event.id.uuidString)
        }
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferOpenedEvent did not match chain ID of OfferStruct in handleOfferOpenedEvent call. OfferOpenedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID) + ", OfferOpenedEvent.id: " + event.id.uuidString)
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
            chainID: offerStruct.chainID
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
            chainID: String(offer.chainID)
        )
        try databaseService.storeOffer(offer: offerForDatabase)
        var settlementMethodStrings: [String] = []
        for settlementMethod in offer.onChainSettlementMethods {
            settlementMethodStrings.append(settlementMethod.base64EncodedString())
        }
        try databaseService.storeSettlementMethods(offerID: offerForDatabase.id, _chainID: offerForDatabase.chainID, settlementMethods: settlementMethodStrings)
        offerOpenedEventRepository.remove(event)
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferOpenedEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            offerTruthSource!.offers[offer.id] = offer
        }
        #warning("TODO: try to get public key announcement data. if we have it, update the offer struct and add it to the ViewModel's list")
    }
    
    #warning("TODO: when we support multiple chains, someone could corrupt the interface's knowledge of settlement methods on Chain A by creating another offer with the same ID on Chain B and then changing the settlement methods of the offer on Chain B. If this interface is listening to both, it will detect the OfferEditedEvent from Chain B and then use the settlement methods from the offer on Chain B to update its local Offer object corresponding to the object from Chain A. We should only update settlement methods if the chainID of the OfferEditedEvent matches that of the already-stored offer")
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferEditedEvent`. Once notified, `OfferService` saves `event` in `offerEditedEventsRepository`, gets updated on-chain offer data by calling `blockchainService`'s `getOffer` method, verifies that the chain ID of the event and the offer data match, creates an updated `Offer` with the results, updates the settlement methods of the corresponding persistently stored offer, removes `event` from `offerEditedEventsRepository`, and then synchronously maps the offer's ID to the updated `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferEditedEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError` or `OfferServiceError.nonmatchingChainIDError`.
     */
    func handleOfferEditedEvent(_ event: OfferEditedEvent) throws {
        offerEditedEventRepository.append(event)
        guard blockchainService != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferEditedEvent call")
        }
        // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
        guard let offerStruct = try blockchainService!.getOffer(id: event.id) else {
            throw OfferServiceError.unexpectedNilError(desc: "No on-chain offer was found with ID specified in OfferEditedEvent in handleOfferEditedEvent call. OfferEditedEvent.id: " + event.id.uuidString)
        }
        guard event.chainID == offerStruct.chainID else {
            throw OfferServiceError.nonmatchingChainIDError(desc: "Chain ID of OfferEditedEvent did not match chain ID of OfferStruct in handleOfferEditedEvent call. OfferEditedEvent.chainID: " + String(event.chainID) + ", OfferStruct.chainID: " + String(offerStruct.chainID))
        }
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
            chainID: offerStruct.chainID
        ) else {
            throw OfferServiceError.unexpectedNilError(desc: "Got nil while creating Offer from OfferStruct data during handleOfferEditedEvent call. OfferEditedEvent.id: " + event.id.uuidString)
        }
        let offerIdString = offer.id.asData().base64EncodedString()
        var settlementMethodStrings: [String] = []
        for settlementMethod in offerStruct.settlementMethods {
            settlementMethodStrings.append(settlementMethod.base64EncodedString())
        }
        try databaseService.storeSettlementMethods(offerID: offerIdString, _chainID: String(offer.chainID), settlementMethods: settlementMethodStrings)
        offerEditedEventRepository.remove(event)
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferEditedEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            offerTruthSource!.offers[offer.id] = offer
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferCanceledEvent`. Once notified, `OfferService` saves `event` in `offerCanceledEventsRepository`, removes the corresponding offer and its settlement methods from persistent storage, removes `event` from `offerCanceledEventsRepository`, and then checks that the chain ID of the event matches the chain ID of the `Offer` mapped to the offer ID specified in `event` in `offerTruthSource`;s `offers` dictionary on the main thread. If they do not match, this returns. If they do match, then this synchronously removes the `Offer` from said `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferCanceledEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) throws {
        let offerIdString = event.id.asData().base64EncodedString()
        offerCanceledEventRepository.append(event)
        try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
        try databaseService.deleteSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
        offerCanceledEventRepository.remove(event)
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferCanceledEvent call. ")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            if offerTruthSource!.offers[event.id]?.chainID == event.chainID {
                offerTruthSource!.offers.removeValue(forKey: event.id)
            }
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferTakenEvent`. Once notified, `OfferService` saves `event` in `offerTakenEventsRepository`, removes the corresponding offer and its settlement methods from persistent storage, removes `event` from `offerTakenEventsRepository`, and then checks that the chain ID of the event matches the chain ID of the `Offer` mapped to the offer ID specified in `event` in `offerTruthSource`'s `offers` dictionary on the main thread. If they do not match, this returns. If they do match, then this synchronously removes the `Offer` from said `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferTakenEvent` of which `OfferService` is being notified.
     
     - Throws: `OfferServiceError.unexpectedNilError`if `offerTruthSource` is nil.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) throws {
        let offerIdString = event.id.asData().base64EncodedString()
        offerTakenEventRepository.append(event)
        try databaseService.deleteOffers(offerID: offerIdString, _chainID: String(event.chainID))
        try databaseService.deleteSettlementMethods(offerID: offerIdString, _chainID: String(event.chainID))
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
    }
    
}

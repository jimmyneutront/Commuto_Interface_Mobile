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
class OfferService: OfferNotifiable {
    
    /**
     Initializes a new OfferService object.
     
     - Parameter databaseService: The `DatabaseService` that the `OfferService` will use for persistent storage.
     */
    init(databaseService: DatabaseService, offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent> = BlockchainEventRepository<OfferOpenedEvent>()) {
        self.databaseService = databaseService
        self.offerOpenedEventRepository = offerOpenedEventRepository
    }
    
    /**
     An object adopting `OfferTruthSource` in which this is responsible for maintaining an accurate list of all open offers.
     */
    var offerTruthSource: OfferTruthSource? = nil
    /**
     The `BlockchainService` that this uses for interacting with the blockchain.
     */
    var blockchainService: BlockchainService? = nil
    
    /**
     The `DatabaseService` that this uses for persistent storage.
     */
    private let databaseService: DatabaseService
    
    #warning("this should be an object with a default value in the initializer, so we can inject a test object to ensure events are created and removed properly")
    /**
     An `Array` of `OfferOpenedEvent`s for offers that are open and for which complete offer information has not yet been retrieved.
     */
    private var offerOpenedEventRepository: BlockchainEventRepository<OfferOpenedEvent>
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferOpenedEvent`. Once notified, `OfferService` persistently stores `event`, saves it in `offerOpenedEventsRepository`, gets all on-chain offer data by calling `blockchainServices's` `getOffer` method, creates a new `Offer` with the results, and then synchronously maps the offer's ID to the new `Offer` in `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferOpenedEvent` of which `OfferService` is being notified.
     */
    func handleOfferOpenedEvent(_ event: OfferOpenedEvent) throws {
        // Save the passed OfferOpenedEvent persistently
        try databaseService.storeOfferOpenedEvent(
            id: event.id.asData().base64EncodedString(),
            interfaceId: event.interfaceId.base64EncodedString()
        )
        offerOpenedEventRepository.append(event)
        guard blockchainService != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "blockchainService was nil during handleOfferOpenedEvent call")
        }
        // Force unwrapping blockchainService is safe from here forward because we ensured that it is not nil
        let offerStruct = try blockchainService!.getOffer(id: event.id)
        let offer = Offer(
            id: event.id,
            direction: "Buy",
            price: "1.004",
            pair: "USD/UST",
            isCreated: offerStruct.isCreated,
            isTaken: offerStruct.isTaken,
            maker: offerStruct.maker,
            interfaceId: event.interfaceId,
            stablecoin: offerStruct.stablecoin,
            amountLowerBound: offerStruct.amountLowerBound,
            amountUpperBound: offerStruct.amountUpperBound,
            securityDepositAmount: offerStruct.securityDepositAmount,
            serviceFeeRate: offerStruct.serviceFeeRate,
            onChainDirection: offerStruct.direction,
            onChainPrice: offerStruct.price,
            settlementMethods: offerStruct.settlementMethods,
            protocolVersion: offerStruct.protocolVersion
        )
        #warning("TODO: save to offer database")
        guard offerTruthSource != nil else {
            throw OfferServiceError.unexpectedNilError(desc: "offerTruthSource was nil during handleOfferOpenedEvent call")
        }
        // Force unwrapping offerTruthSource is safe from here forward because we ensured that it is not nil
        DispatchQueue.main.sync {
            offerTruthSource!.offers[offer.id] = offer
        }
        #warning("TODO: remove OfferOpenedEvent from database now that we have offer info")
        offerOpenedEventRepository.remove(event)
        #warning("TODO: try to get public key announcement data. if we have it, update the offer struct and add it to the ViewModel's list")
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferCanceledEvent`. Once notified, `OfferService` gets the ID of the now-canceled offer from `event` and then synchronously removes the `Offer` mapped to the ID specified in `event` from `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferCanceledEvent` of which `OfferService` is being notified.
     */
    func handleOfferCanceledEvent(_ event: OfferCanceledEvent) {
        _ = DispatchQueue.main.sync {
            offerTruthSource?.offers.removeValue(forKey: event.id)
        }
    }
    
    /**
     The function called by `BlockchainService` to notify `OfferService` of an `OfferTakenEvent`. Once notified, `OfferService` gets the ID of the now-taken offer from `event` and then synchronously removes the `Offer` mapped to the ID specified in `event` from `offerTruthSource`'s `offers` dictionary on the main thread.
     
     - Parameter event: The `OfferTakenEvent` of which `OfferService` is being notified.
     */
    func handleOfferTakenEvent(_ event: OfferTakenEvent) {
        _ = DispatchQueue.main.sync {
            offerTruthSource?.offers.removeValue(forKey: event.id)
        }
    }
    
}

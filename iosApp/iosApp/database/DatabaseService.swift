//
//  DatabaseService.swift
//  iosApp
//
//  Created by jimmyt on 11/27/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import SQLite

/**
 The Database Service Class.
 
 This is responsible for storing data, serving it to other services upon request, and accepting services' requests to add and remove data from storage.
 */
class DatabaseService {
    
    /**
     Creates a new `DatabaseService`, and creates an in-memory database with its reference stored in `DatabaseService`'s `connection` property.
     */
    init() throws {
        connection = try Connection(.inMemory)
    }
    
    /**
     The connection to the SQLite database.
     */
    var connection: Connection
    
    /**
     The serial DispatchQueue used to synchronize database access. All database queries should be run on this queue to prevent data races.
     */
    let databaseQueue = DispatchQueue(label: "databaseService.serial.queue")
    
    /**
     A database table of `Offer`s.
     */
    let offers = Table("Offer")
    /**
     A database table of settlement methods, as Base-64 `String` encoded  bytes.
     */
    let settlementMethods = Table("SettlementMethod")
    /**
     A database table of [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events.
     */
    let offerOpenedEvents = Table("OfferOpenedEvent")
    /**
     A database table of [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled)
     */
    let offerCanceledEvents = Table("OfferCanceledEvent")
    /**
     A database table of `KeyPair`s.
     */
    let keyPairs = Table("KeyPair")
    /**
     A database table of `PublicKey`s.
     */
    let publicKeys = Table("PublicKey")
    
    /**
     A database structure representing an offer ID.
     */
    let offerId = Expression<String>("offerId")
    /**
     A database structure representing an interface ID.
     */
    let interfaceId = Expression<String>("interfaceId")
    /**
     A database structure representing a public key.
     */
    let publicKey = Expression<String>("publicKey")
    /**
     A database structure representing a private key.
     */
    let privateKey = Expression<String>("privateKey")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `isCreated` property.
     */
    let isCreated = Expression<Bool>("isCreated")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `isTaken` property.
     */
    let isTaken = Expression<Bool>("isTaken")
    /**
     A database structure representing the maker of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    let maker = Expression<String>("maker")
    /**
     A database structure representing a stablecoin smart contract address.
     */
    let stablecoin = Expression<String>("stablecoin")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `amountLowerBound` property.
     */
    let amountLowerBound = Expression<String>("amountLowerBound")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `amountUpperBound` property.
     */
    let amountUpperBound = Expression<String>("amountUpperBound")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `securityDepositAmount` property.
     */
    let securityDepositAmount = Expression<String>("securityDepositAmount")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `serviceFeeRate` property.
     */
    let serviceFeeRate = Expression<String>("serviceFeeRate")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `onChainDirection` property.
     */
    let onChainDirection = Expression<String>("onChainDirection")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `onChainPrice` property.
     */
    let onChainPrice = Expression<String>("onChainPrice")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `protocolVersion` property.
     */
    let protocolVersion = Expression<String>("protocolVersion")
    /**
     A database structure representing a particular settlement method of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    let settlementMethod = Expression<String>("settlementMethod")
    
    /**
     Creates all necessary database tables.
     */
    func createTables() throws {
        try connection.run(offers.create { t in
            t.column(offerId, unique: true)
            t.column(isCreated)
            t.column(isTaken)
            t.column(maker)
            t.column(interfaceId)
            t.column(stablecoin)
            t.column(amountLowerBound)
            t.column(amountUpperBound)
            t.column(securityDepositAmount)
            t.column(serviceFeeRate)
            t.column(onChainDirection)
            t.column(onChainPrice)
            t.column(protocolVersion)
        })
        try connection.run(settlementMethods.create { t in
            t.column(offerId)
            t.column(settlementMethod)
        })
        try connection.run(offerOpenedEvents.create { t in
            t.column(offerId, unique: true)
            t.column(interfaceId)
        })
        try connection.run(offerCanceledEvents.create { t in
            t.column(offerId, unique: true)
        })
        try connection.run(keyPairs.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
            t.column(privateKey)
        })
        try connection.run(publicKeys.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
        })
    }
    
    /**
     Persistently stores a `DatabaseOffer`. If a `DatabaseOffer` with an offer ID equal to that of `offer` already exists in the database, this does nothing.
     
     - Parameter offer: The `offer` to be persistently stored.
     */
    func storeOffer(offer: DatabaseOffer) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(offers.insert(
                    offerId <- offer.id,
                    isCreated <- offer.isCreated,
                    isTaken <- offer.isTaken,
                    maker <- offer.maker,
                    interfaceId <- offer.interfaceId,
                    stablecoin <- offer.stablecoin,
                    amountLowerBound <- offer.amountLowerBound,
                    amountUpperBound <- offer.amountUpperBound,
                    securityDepositAmount <- offer.securityDepositAmount,
                    serviceFeeRate <- offer.serviceFeeRate,
                    onChainDirection <- offer.onChainDirection,
                    onChainPrice <- offer.onChainPrice,
                    protocolVersion <- offer.protocolVersion
                ))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: Offer.offerId" {
                // An Offer with the specified id already exists in the database, so we do nothing
            }
        }
    }
    
    /**
     Removes every `DatabaseOffer` with an offer ID equal to `id` from persistent storage.
     
     - Parameter id: The ID of the offers to be removed, as a Base64-`String` of bytes.
     */
    func deleteOffers(id: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(offerId == id).delete())
        }
    }
    
    /**
     Retrieves the persistently stored `DatabaseOffer` with the specified offer ID, or returns `nil` if no such event is present.
     
     - Parameter id: The offer ID of the `DatabaseOffer` to return, as a Base64-`String` of bytes.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is `nil`, and a `DatabaseServiceError.unexpectedQueryResult` if `DatabaseOffer`s are found with the same offer ID or if the offer ID of the `DatabaseOffer` returned from the database does not match `id`.
     
     - Returns: A `DatabaseOffer` corresponding to `id`, or `nil` if no such event is found.
     */
    func getOffer(id: String) throws -> DatabaseOffer? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(offers.filter(offerId == id))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getOffer call")
        }
        let result = try Array(rowIterator!)
        if result.count > 1 {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple Offers found with given offer id" + id)
        } else if result.count == 1 {
            guard result[0][offerId] == id else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Offer ID of returned Offer did not match specified offer ID " + id)
            }
            return DatabaseOffer(
                id: result[0][offerId],
                isCreated: result[0][isCreated],
                isTaken: result[0][isTaken],
                maker: result[0][maker],
                interfaceId: result[0][interfaceId],
                stablecoin: result[0][stablecoin],
                amountLowerBound: result[0][amountLowerBound],
                amountUpperBound: result[0][amountUpperBound],
                securityDepositAmount: result[0][securityDepositAmount],
                serviceFeeRate: result[0][serviceFeeRate],
                onChainDirection: result[0][onChainDirection],
                onChainPrice: result[0][onChainPrice],
                protocolVersion: result[0][protocolVersion]
            )
        } else {
            return nil
        }
    }
    
    #warning("TODO: evantually this should delete all payment methods associated with the specified ID before storing any new ones, so in case the offer is edited, we don't have any unsupported payment methods still in persistent storage.")
    /**
     Persistently stores each settlement method in the supplied `Array`, associating each one with the supplied ID.
     
     - Parameters:
        - id: The ID of the offer or swap to be associated with the settlement methods.
        - settlementMethods: The settlement methods to be persistently stored.
     */
    func storeSettlementMethods(id: String, settlementMethods _settlementMethods: [String]) throws {
        _ = try databaseQueue.sync {
            for _settlementMethod in _settlementMethods {
                try connection.run(settlementMethods.insert(
                    offerId <- id,
                    settlementMethod <- _settlementMethod
                ))
            }
        }
    }
    
    /**
     Removes every persistently stored settlement method associated with an offer ID equal to `id`.
     
     - Parameter id: The ID of the offer for which associated settlement methods should be removed.
     */
    func deleteSettlementMethods(id: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(settlementMethods.filter(offerId == id).delete())
        }
    }

    /**
     Retrieves the persistently stored settlement methods associated with the specified offer ID, or returns `nil` if no such settlement methods are present.
     
     - Parameter id: The ID of the offer for which settlement methods should be returned, as a Base64-`String` of bytes.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is `nil`.
     
     - Returns: An `Array` of `Strings` which are settlement methods associated with `id`, or `nil` if no such settlement  methods are found.
     */
    func getSettlementMethods(id: String) throws -> [String]? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(settlementMethods.filter(offerId == id))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getSettlementMethods call")
        }
        let result = try Array(rowIterator!)
        if result.count > 0 {
            var settlementMethodsArray: [String] = []
            for (index, _) in result.enumerated() {
                settlementMethodsArray.append(result[index][settlementMethod])
            }
            return settlementMethodsArray
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores the contents of an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) Event. If an OfferOpened event with an offer ID equal to `id` already exists in the database, this does nothing.
     
     - Parameters:
        - id: The offer ID specified in the OfferOpened event, as a Base64-`String` of its bytes.
        - interfaceId: The interface ID specified in the OfferOpened event, as a Base64-`String` of bytes.
     */
    func storeOfferOpenedEvent(id: String, interfaceId: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(offerOpenedEvents.insert(offerId <- id, self.interfaceId <- interfaceId))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: OfferOpenedEvent.offerId" {
                // An OfferOpened event with the specified id already exists in the database, so we do nothing
            }
        }
    }
    
    /**
     Removes every [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) Event with an offer ID equal to `id` from persistent storage.
     
     - Parameter id: The offer ID of the OfferOpened events to be removed, as a Base64-`String` of bytes.
     */
    func deleteOfferOpenedEvents(id: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offerOpenedEvents.filter(offerId == id).delete())
        }
    }
    
    /**
     Retrieves the persistently stored OfferOpened event with the given offer ID, or returns `nil` if no such event is present.
     
     - Parameter id: The offer ID of the OfferOpened event to return, as a Base64-`String` of bytes.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple events are found with the same offer ID or if the offer ID of the event returned from the database does not match `id`.
     
     - Returns: A `DatabaseOfferOpenedEvent` corresponding to `id`, or `nil` if no such event is found.
     */
    func getOfferOpenedEvent(id: String) throws -> DatabaseOfferOpenedEvent? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(offerOpenedEvents.filter(offerId == id))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getOfferOpenedEvent call")
        }
        let result = try Array(rowIterator!)
        if result.count > 1 {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple OfferOpened events found with given offer id" + id)
        } else if result.count == 1 {
            guard result[0][offerId] == id else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Offer ID of returned OfferOpened event did not match specified offer ID " + id)
            }
            return DatabaseOfferOpenedEvent(id: result[0][offerId], interfaceId: result[0][interfaceId])
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores the contents of an [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) Event. If an OfferCanceled event with an offer ID equal to `id` already exists in the database, this does nothing.
     
     - Parameter id: The offer ID specified in the OfferCanceled event, as a Base64-`String` of its bytes.
     */
    func storeOfferCanceledEvent(id: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(offerCanceledEvents.insert(offerId <- id))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: OfferCanceledEvent.offerId" {
                // An OfferCanceled event with the specified id already exists in the database, so we do nothing.
            }
        }
    }
    
    /**
     Removes every [OfferCanceled](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offercanceled) Event with an offer ID equal to `id` from persistent storage.
     
     - Parameter id: The offer ID of the OfferCanceled events to be removed, as a Base64-`String` of bytes.
     */
    func deleteOfferCanceledEvents(id: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offerCanceledEvents.filter(offerId == id).delete())
        }
    }
    
    /**
     Retrieves the persistently stored OfferCanceled event with the given offer ID, or returns `nil` if no such event is present.
     
     - Parameter id: The offer ID of the OfferCanceled event to return as a Base64-`String` of bytes.`
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple events are found with the same offer ID or if the offer ID of the event returned from the database does not match `id`.
     
     - Returns: A `DatabaseOfferCanceledEvent` corresponding to `id` or `nil` if no such event is found.
     */
    func getOfferCanceledEvent(id: String) throws -> DatabaseOfferCanceledEvent? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(offerCanceledEvents.filter(offerId == id))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getOfferCanceledEvent call")
        }
        let result = try Array(rowIterator!)
        if result.count > 1 {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple OfferCanceled events found with given offer id" + id)
        } else if result.count == 1 {
            guard result[0][offerId] == id else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Offer ID of returned OfferCanceled event did not match specified offer ID " + id)
            }
            return DatabaseOfferCanceledEvent(id: result[0][offerId])
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores a key pair associated with an interface ID.
     
     - Note: This function is used exclusively by `KeyManagerService`
     
     - Parameters:
        - interfaceId: The interface ID of the key pair as a byte array encoded to a hexadecimal `String`.
        - publicKey: The public key of the key pair as a byte array encoded to a hexadecimal `String`.
        - privateKey: The private key of the key pair as a byte array encoded to a hexadecimal `String`.
     */
    func storeKeyPair(interfaceId interf_id: String, publicKey pub_key: String, privateKey priv_key: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(keyPairs.insert(interfaceId <- interf_id, publicKey <- pub_key, privateKey <- priv_key))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: KeyPair.interfaceId" {
                // A KeyPair with the specified interface ID already exists in the database, so we do nothing
            }
        }
    }
    
    /**
     Retrieves the persistently stored key pair associated with the given interface ID, or returns `nil` if no such key pair is present.
     
     - Parameter interfaceId: The interface ID of the desired key pair as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DatabaseKeyPair` if a key pair with the specified interface ID is found, or `nil` if such a key pair is not found.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple key pairs are found with the same interface ID or if the interface ID of the key pair returned from the database does not match `interfaceId`.
     */
    func getKeyPair(interfaceId interfId: String) throws -> DatabaseKeyPair? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(keyPairs.filter(interfaceId == interfId))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getKeyPair call")
        }
        let result = try Array(rowIterator!)
        if (result.count > 1) {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple key pairs found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            return DatabaseKeyPair(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey], privateKey: result[0][privateKey])
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores a public key associated with an interface ID.
     
     - Parameters:
        - interfaceId: The interface ID of the key pair as a byte array encoded to a hexadecimal `String`.
        - publicKey: The public key to be stored, as a byte array encoded to a hexadecimal `String`.
     */
    func storePublicKey(interfaceId interf_id: String, publicKey pub_key: String) throws {
        _ = try databaseQueue.sync {
            do {
                try connection.run(publicKeys.insert(interfaceId <- interf_id, publicKey <- pub_key))
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: PublicKey.interfaceId" {
                // A PublicKey with the specified interface ID already exists in the database, so we do nothing
            }
        }
    }
    
    /**
     Retrieves the persistently stored public key associated with the given interface ID, or returns `nil` if no such key is found.
     
     - Parameter interfaceId: The interface ID of the public key as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DatabasePublicKey` if a public key with the specified interface ID is found, or `nil` if no such public key is found.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is nil, and a `DatabaseServiceError.unexpectedQueryResult` if multiple public keys are found with the same interface ID or if the interface ID of the public key returned from the database does not match `interfaceId`.
     */
    func getPublicKey(interfaceId interfId: String) throws -> DatabasePublicKey? {        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(publicKeys.filter(interfaceId == interfId))
        }
        guard rowIterator != nil else {
            throw DatabaseServiceError.unexpectedNilError(desc: "rowIterator was nil after query during getPublicKey call")
        }
        let result = try Array(rowIterator!)
        if (result.count > 1) {
            throw DatabaseServiceError.unexpectedQueryResult(message: "Multiple public keys found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DatabaseServiceError.unexpectedQueryResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            return DatabasePublicKey(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey])
        } else {
            return nil
        }
    }
    
}

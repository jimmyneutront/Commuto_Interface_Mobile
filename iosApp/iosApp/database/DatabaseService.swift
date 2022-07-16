//
//  DatabaseService.swift
//  iosApp
//
//  Created by jimmyt on 11/27/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import os
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
     DatabaseService's `Logger`.
     */
    private let logger = Logger(subsystem: "xyz.commuto.interfacemobile", category: "DatabaseService")
    
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
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `direction` property.
     */
    let onChainDirection = Expression<String>("onChainDirection")
    /**
     A database structure representing an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer)'s `protocolVersion` property.
     */
    let protocolVersion = Expression<String>("protocolVersion")
    /**
     A database structure representing a blockchain ID.
     */
    let chainID = Expression<String>("chainID")
    /**
     A database structure representing a particular settlement method of an [Offer](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offer).
     */
    let settlementMethod = Expression<String>("settlementMethod")
    /**
     A database structure  representing an Offer's `havePublicKey` property.
     */
    let havePublicKey = Expression<Bool>("havePublicKey")
    
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
            t.column(protocolVersion)
            t.column(chainID)
            t.column(havePublicKey)
        })
        try connection.run(settlementMethods.create { t in
            t.column(offerId)
            t.column(chainID)
            t.column(settlementMethod)
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
                    protocolVersion <- offer.protocolVersion,
                    chainID <- offer.chainID,
                    havePublicKey <- offer.havePublicKey
                ))
                logger.notice("storeOffer: stored offer with B64 ID \(offer.id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: Offer.offerId" {
                // An Offer with the specified id already exists in the database, so we do nothing
                logger.notice("storeOffer: offer with B64 ID \(offer.id) already exists in database")
            }
        }
    }
    
    /**
     Updates a persistently stored `DatabaseOffer`'s `havePublicKey` field.
     
     - Parameters:
        - offerID: The ID of the offer to be updated, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offer to be updated, as a `String`.
        - havePublicKey: The new value that will be assigned to the persistently stored `DatabaseOffer`'s `havePublicKey` field.
     */
    func updateOfferHavePublicKey(offerID: String, _chainID: String, _havePublicKey: Bool) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(offerId == offerID && chainID == _chainID).update(havePublicKey <- _havePublicKey))
        }
        logger.notice("updateOfferHavePublicKey: set value to \(_havePublicKey) for offer with B64 ID \(offerID), if present")
    }
    
    /**
     Removes every `DatabaseOffer` with an offer ID equal to `offerID` and a chain ID equal to `chainID` from persistent storage.
     
     - Parameters:
        - offerID: The ID of the offers to be removed, as a Base64-`String` of bytes.
        - chainID: The chain ID of the offers to be removed, as a `String`.
     */
    func deleteOffers(offerID: String, _chainID: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(offers.filter(offerId == offerID && chainID == _chainID).delete())
        }
        logger.notice("deleteOffers: deleted offers with B64 ID \(offerID) and chain ID \(_chainID), if present")
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
            logger.notice("getOffer: returning offer with B64 ID \(id)")
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
                protocolVersion: result[0][protocolVersion],
                chainID: result[0][chainID],
                havePublicKey: result[0][havePublicKey]
            )
        } else {
            logger.notice("getOffer: no offer found with B64 ID \(id)")
            return nil
        }
    }
    
    /**
     Deletes all persistently stored settlement methods associated with the specified offer ID and chain ID, and then persistently stores each settlement method in the supplied `Array`, associating each one with the supplied offer ID and chain ID.
     
     - Parameters:
        - offerID: The ID of the offer or swap to be associated with the settlement methods.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
        - settlementMethods: The settlement methods to be persistently stored.
     */
    func storeSettlementMethods(offerID: String, _chainID: String, settlementMethods _settlementMethods: [String]) throws {
        _ = try databaseQueue.sync {
            try connection.run(settlementMethods.filter(offerId == offerID && chainID == _chainID).delete())
            for _settlementMethod in _settlementMethods {
                try connection.run(settlementMethods.insert(
                    offerId <- offerID,
                    chainID <- _chainID,
                    settlementMethod <- _settlementMethod
                ))
            }
        }
        logger.notice("storeSettlementMethods: stored \(_settlementMethods.count) for offer with B64 ID \(offerID)")
    }
    
    /**
     Removes every persistently stored settlement method associated with an offer ID equal to `offerID` and a chain ID equal to `chainID`.
     
     - Parameters:
        - offerID: The ID of the offer for which associated settlement methods should be removed.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
     */
    func deleteSettlementMethods(offerID: String, _chainID: String) throws {
        _ = try databaseQueue.sync {
            try connection.run(settlementMethods.filter(offerId == offerID && chainID == _chainID).delete())
        }
        logger.notice("deleteSettlementMethods: deleted for offer with B64 ID \(offerID)")
    }

    /**
     Retrieves the persistently stored settlement methods associated with the specified offer ID and chain ID, or returns `nil` if no such settlement methods are present.
     
     - Parameters:
        - offerID: The ID of the offer for which settlement methods should be returned, as a Base64-`String` of bytes.
        - chainID: The ID of the blockchain on which the `Offer` or `Swap` corresponding to these settlement methods exists, as a `String`.
     
     - Throws: A `DatabaseServiceError.unexpectedNilError` if `rowIterator` is `nil`.
     
     - Returns: An `Array` of `Strings` which are settlement methods associated with `id`, or `nil` if no such settlement  methods are found.
     */
    func getSettlementMethods(offerID: String, _chainID: String) throws -> [String]? {
        var rowIterator: RowIterator? = nil
        _ = try databaseQueue.sync {
            rowIterator = try connection.prepareRowIterator(settlementMethods.filter(offerId == offerID && chainID == _chainID))
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
            logger.notice("getSettlementMethods: returning \(settlementMethodsArray.count) for offer with B64 ID \(offerID)")
            return settlementMethodsArray
        } else {
            logger.notice("getSettlementMethods: none found for offer with B64 ID \(offerID)")
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
                logger.notice("storeKeyPair: stored with interface ID \(interf_id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: KeyPair.interfaceId" {
                // A KeyPair with the specified interface ID already exists in the database, so we do nothing
                logger.notice("storeKeyPair: key pair with interface ID \(interf_id) already exists in database")
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
            logger.notice("getKeyPair: returning key pair with interface ID \(interfId)")
            return DatabaseKeyPair(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey], privateKey: result[0][privateKey])
        } else {
            logger.notice("getKeyPair: no key pair found with interface ID \(interfId)")
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
                logger.notice("storePublicKey: stored with interface ID \(interf_id)")
            } catch SQLite.Result.error(let message, _, _) where message == "UNIQUE constraint failed: PublicKey.interfaceId" {
                // A PublicKey with the specified interface ID already exists in the database, so we do nothing
                logger.notice("storePublicKey: public key with interface ID \(interf_id) already exists in database")
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
            logger.notice("getPublicKey: returning public key with interface ID \(interfId)")
            return DatabasePublicKey(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey])
        } else {
            logger.notice("getPublicKey: no public key found with interface ID \(interfId)")
            return nil
        }
    }
    
}

//
//  DBService.swift
//  iosApp
//
//  Created by jimmyt on 11/27/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import SQLite

#warning("TODO: rename this as DatabaseService")
/**
 The Database Service Class.
 
 This is responsible for storing data, serving it to other services upon request, and accepting services' requests to add and remove data from storage.
 */
class DBService {
    
    #warning("TODO: rename this as connection")
    /**
     The connection to the SQLite database.
     */
    var db: Connection?
    
    /**
     The serial DispatchQueue used to synchronize database access. All database queries should be run on this queue to prevent data races.
     */
    let databaseQueue = DispatchQueue(label: "databaseService.serial.queue")
    
    /**
     A database table of [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) events.
     */
    let offerOpenedEvents = Table("OfferOpenedEvent")
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
    
    #warning("This should get its own file")
    /**
     An `Error` thrown by `DatabaseService` functions.
     */
    enum DBServiceError: Error {
        /**
         Thrown when `DatabaseService` receives an unexpected result from a database query.
         
         - Parameter message: A `String` that provides information about the context in which the error was thrown.
         */
        case unexpectedDbResult(message: String)
    }
    
    /**
     Creates all necessary database tables.
     */
    func createTables() throws {
        try db!.run(keyPairs.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
            t.column(privateKey)
        })
        try db!.run(publicKeys.create { t in
            t.column(interfaceId, unique: true)
            t.column(publicKey)
        })
        try db!.run(offerOpenedEvents.create { t in
            t.column(offerId, unique: true)
            t.column(interfaceId)
        })
    }
    
    /**
     Creates a new in-memory database, and stores its reference in `DatabaseService`'s `db` property.
     */
    func connectToDb() throws {
        db = try Connection(.inMemory)
    }
    
    /**
     Persistently stores the contents of an [OfferOpened](https://www.commuto.xyz/docs/technical-reference/core-tec-ref#offeropened) Event.
     
     - Parameters:
        - id: The offer ID specified in the OfferOpened event, as a `String`.
        - interfaceId: The interface ID specified in the OfferOpened event, as a `String`.
     */
    func storeOfferOpenedEvent(id: String, interfaceId: String) throws {
        _ = try databaseQueue.sync {
            try db!.run(offerOpenedEvents.insert(offerId <- id, self.interfaceId <- interfaceId))
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
        guard try getKeyPair(interfaceId: interf_id) == nil else {
            throw DBServiceError.unexpectedDbResult(message: "Database query for key pair with interface id " + interf_id + " returned result")
        }
        try db!.run(keyPairs.insert(interfaceId <- interf_id, publicKey <- pub_key, privateKey <- priv_key))
    }
    
    /**
     Retrieves the persistently stored key pair associated with the given interface ID, or returns `nil` if no such key pair is present.
     
     - Parameter interfaceId: The interface ID of the desired key pair as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DBKeyPair` if a key pair with the specified interface ID is found, or `nil` if such a key pair is not found.
     
     - Throws: A `DBServiceError.inexpectedDbResult` if multiple key pairs are found for a single interface ID, or if the interface ID of the key pair returned from the database query does not match `interfaceId`.
     */
    func getKeyPair(interfaceId interfId: String) throws -> DBKeyPair? {
        let rowIterator = try db!.prepareRowIterator(keyPairs.filter(interfaceId == interfId))
        let result = try Array(rowIterator)
        if (result.count > 1) {
            throw DBServiceError.unexpectedDbResult(message: "Multiple key pairs found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DBServiceError.unexpectedDbResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            return DBKeyPair(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey], privateKey: result[0][privateKey])
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores a public key associated with an interface ID.
     
     - Parameters:
        - interfaceId: The interface ID of the key pair as a byte array encoded to a hexadecimal `String`.
        - publicKey: The public key to be stored, as a byte array encoded to a hexadecimal `String`.
     
     - Throws: `DBServiceError.unexpectedDbResult` if a public key with the given interface ID is already found in the database.
     */
    func storePublicKey(interfaceId interf_id: String, publicKey pub_key: String) throws {
        guard try getPublicKey(interfaceId: interf_id) == nil else {
            throw DBServiceError.unexpectedDbResult(message: "Database query for public key with interface id " + interf_id + " returned result")
        }
        try db!.run(publicKeys.insert(interfaceId <- interf_id, publicKey <- pub_key))
    }
    
    /**
     Retrieves the persistently stored public key associated with the given interface ID, or returns `nil` if no such key is found.
     
     - Parameter interfaceId: The interface ID of the public key as a byte array encoded to a hexadecimal `String`.
     
     - Returns: A `DBPublicKey` if a public key with the specified interface ID is found, or `nil` if no such public key is found.
     
     - Throws: `DBServiceError.unexpectedDbResult` if multiple public keys are found for a given interface ID, or if the interface ID of the public key returned from the database query does not match `interfaceId`.
     */
    func getPublicKey(interfaceId interfId: String) throws -> DBPublicKey? {
        let rowIterator = try db!.prepareRowIterator(publicKeys.filter(interfaceId == interfId))
        let result = try Array(rowIterator)
        if (result.count > 1) {
            throw DBServiceError.unexpectedDbResult(message: "Multiple public keys found with given interface id " + interfId)
        } else if (result.count == 1) {
            guard result[0][interfaceId] == interfId else {
                throw DBServiceError.unexpectedDbResult(message: "Returned interface id " + result[0][interfaceId] + " did not match specified interface id " + interfId)
            }
            return DBPublicKey(interfaceId: result[0][interfaceId], publicKey: result[0][publicKey])
        } else {
            return nil
        }
    }
    
}

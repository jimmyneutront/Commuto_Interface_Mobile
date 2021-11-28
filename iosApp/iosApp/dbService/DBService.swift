//
//  DBService.swift
//  iosApp
//
//  Created by James Telzrow on 11/27/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import Foundation
import SQLite

/**
 * The Database Service Class.
 *
 * This is responsible for storing data, serving it to Local Services upon request, and accepting
 * Local Services' requests to add and remove data from storage.
 */
class DBService {
    //TODO: Localize error strings
    
    var db: Connection?
    let keyPairs = Table("KeyPair")
    let publicKeys = Table("PublicKey")
    
    //KeyPair and PublicKey table expressions
    let interfaceId = Expression<String>("interfaceId")
    let publicKey = Expression<String>("publicKey")
    let privateKey = Expression<String>("privateKey")
    
    //DBService related errors
    enum DBServiceError: Error {
        case unexpectedDbResult(message: String)
    }
    
    /**
     * Creates all necessary tables for proper operations
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
    }
    
    func connectToDb() throws {
        db = try Connection(.inMemory)
    }
    
    //TODO: Update all store funcs to check for unique values
    
    /**
     * Persistently stores a key pair associated with an interface id.
     *
     * -Parameter interfaceId: the interface id of the keypair as a byte array encoded to a hexadecimal String
     * -Parameter publicKey: the public key of the keypair as a byte array encoded to a hexadecimal String
     * -Parameter privateKey: the private key of the keypair as a byte array encoded to a hexadecimal String
     *
     * Used exclusively by KMService
     */
    func storeKeyPair(interfaceId interf_id: String, publicKey pub_key: String, privateKey priv_key: String) throws {
        guard try getKeyPair(interfaceId: interf_id) == nil else {
            throw DBServiceError.unexpectedDbResult(message: "Database query for key pair with interface id " + interf_id + " returned result")
        }
        try db!.run(keyPairs.insert(interfaceId <- interf_id, publicKey <- pub_key, privateKey <- priv_key))
    }
    
    /**
     * Retrieves the persistently stored key pair associated with the given interface id, or returns
     * nil if not present.
     *
     * -Parameter interfaceId: the interface id of the keypair as a byte array encoded to a hexadecimal String
     *
     * -Returns: KeyPair object (defined in com.commuto.interfacedesktop.db) if key pair is found
     * -Returns: nil if key pair is not found
     * -Throws: DBServiceError.unexpectedDbResult if multiple key pairs are found for a given interface id, or if the interface id
     * returned from the database query does not match the interface id passed to getKeyPair
     *
     * Used exclusively by KMService
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
     * Persistently stores a public key associated with an interface id.
     *
     * -Parameter interfaceId: the interface id of the keypair as a byte array encoded to a hexadecimal String
     * -Parameter publicKey: the public key to be stored as a byte array encoded to a hexadecimal String
     *
     * -Throws: DBServiceError.unexpectedDbResult if a public key with the given interface id is already found in the database
     */
    func storePublicKey(interfaceId interf_id: String, publicKey pub_key: String) throws {
        guard try getPublicKey(interfaceId: interf_id) == nil else {
            throw DBServiceError.unexpectedDbResult(message: "Database query for public key with interface id " + interf_id + " returned result")
        }
        try db!.run(publicKeys.insert(interfaceId <- interf_id, publicKey <- pub_key))
    }
    
    /**
     * Retrieves the persistently stored public key associated with the given interface id, or returns
     * nil if not present
     *
     * -Parameter interfaceId: the interface id of the public key as a byte array encoded to a hexadecimal String
     *
     * -Returns: PublicKey object if public key is found
     * -Returns: nil if public key is not found
     * -Throws: DBServiceError.unexpectedDbResult if multiple public keys are found for a given interface id, or if the interface id
     * returned from the database query does not match the interface id passed to getPublicKey
     *
     * Used exclusively by KMService
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

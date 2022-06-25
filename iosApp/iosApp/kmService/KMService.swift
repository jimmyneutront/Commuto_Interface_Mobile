//
//  KMService.swift
//  iosApp
//
//  Created by jimmyt on 11/6/21.
//

import CryptoKit
import Foundation
import Security

#warning("TODO: rename this as KeyManagerService")
/**
 The Key Manager Service Class.
 
 This is responsible for generating, persistently storing and retrieving key pairs, and for storing and retrieving public keys.
 */
class KMService {
    
    /**
     The `DatabaseService` that `KeyManagerService` uses for persistent storage.
     */
    var dbService: DatabaseService
    
    /**
     Creates a new `KeyManagerService`.
     
     - Parameter dbService: The `DatabaseService` that this `KeyManagerService` uses for persistent storage.
     */
    init(dbService: DatabaseService) {
        self.dbService = dbService
    }
    
    /**
     Generates an 2048-bit RSA key pair and computes the key pair's interface ID, which is the SHA-256 hash of the PKCS#1 byte array encoded representation of the public key.
     
     - Parameter storeResult: Indicates whether the generated key pair should be stored persistently using `DatabaseService`. This will usually be left as true, but testing code may set it as false.
     
     - Returns: A `KeyPair`, the private key of which is a 2048-bit RSA private key, and the interface ID of which is the SHA-256 hash of the PKCS#1 encoded byte representation of the `KeyPair`'s public key.
     */
    func generateKeyPair(storeResult: Bool = true) throws -> KeyPair {
        let keyPair = try KeyPair()
        if storeResult {
            let interfaceIdB64Str = keyPair.interfaceId.base64EncodedString()
            let pubKeyB64Str = try keyPair.pubKeyToPkcs1Bytes().base64EncodedString()
            let privKeyB64Str = try keyPair.privKeyToPkcs1Bytes().base64EncodedString()
            try dbService.storeKeyPair(interfaceId: interfaceIdB64Str, publicKey: pubKeyB64Str, privateKey: privKeyB64Str)
        }
        return keyPair
    }
    
    /**
     Retrieves the persistently stored `KeyPair` associated with the specified interface ID, or returns `nil` if such a `KeyPair` is not found.
     
     - Parameter interfaceId: The interface ID of the desired `KeyPair`, which is the SHA-256 hash of the PKCS#1 byte encoded representation of the `KeyPair`'s public key.
     
     - Returns: A `KeyPair`, the private key of which is a 2048-bit RSA key pair such that the SHA-256 hash of the PKCS#1 encoded byte representation of its public key is equal to `interfaceId`, or `nil` if no such `KeyPair` is found.
     */
    func getKeyPair(interfaceId: Data) throws -> KeyPair? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let databaseKeyPair: DatabaseKeyPair? = try dbService.getKeyPair(interfaceId: interfaceIdB64Str)
        if databaseKeyPair != nil {
            let pubKeyBytes = Data(base64Encoded: databaseKeyPair!.publicKey)!
            let privKeyBytes = Data(base64Encoded: databaseKeyPair!.privateKey)!
            return try KeyPair(publicKeyBytes: pubKeyBytes, privateKeyBytes: privKeyBytes)
        } else {
            return nil
        }
    }
    
    /**
     Persistently stores a `PublicKey` in such a way that it can be retrieved again given its interface ID. This will generate a PKCS#1 byte representation of `pubKey`, encode it as a Base64 `String` and store it using `DatabaseService`.
     
     - Parameter pubKey: The `PublicKey` to be persistently stored.
     */
    func storePublicKey(pubKey: PublicKey) throws {
        let interfaceIdB64Str = pubKey.interfaceId.base64EncodedString()
        let pubKeyB64Str = try pubKey.toPkcs1Bytes().base64EncodedString()
        try dbService.storePublicKey(interfaceId: interfaceIdB64Str, publicKey: pubKeyB64Str)
    }
    
    /**
     Retrieves the persistently stored `PublicKey` with an interface ID equal to `interfaceId`, or returns `nil` if no such `PublicKey` is found.
     
     - Parameter interfaceId: The interface ID of the desired `PublicKey`. This is the SHA-256 hash of the desired `PublicKey`'s PKCS#1 byte encoded representation.
     
     - Returns: A `PublicKey`, the SHA-256 hash of the PKCS#1 encoded byte representation of which is equal to `interfaceId`, or `nil` if no such `PublicKey` is found.
     */
    func getPublicKey(interfaceId: Data) throws -> PublicKey? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let dbPubKey: DatabasePublicKey? = try dbService.getPublicKey(interfaceId: interfaceIdB64Str)
        if dbPubKey != nil {
            let pubKeyBytes: Data = Data(base64Encoded: dbPubKey!.publicKey)!
            return try PublicKey(publicKeyBytes: pubKeyBytes)
        } else {
            return nil
        }
    }
}

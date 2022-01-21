//
//  KMService.swift
//  iosApp
//
//  Created by jimmyt on 11/6/21.
//

import CryptoKit
import Foundation
import Security

/**
 * The Key Manager Service Class.
 *
 * This is responsible for generating, storing, and retrieving key pairs, and for storing and retrieving public keys.
 *
 * -Parameter: dbService the Database Service used to store and retrieve data
 */
class KMService {
    
    var dbService: DBService
    init(dbService: DBService) {
        self.dbService = dbService
    }
    
    /**
     * Generates an 2048-bit RSA key pair, and computes the key pair's interface id, which is a SHA-256 hash of the
     * PKCS#1 byte array encoded representation of the public key.
     *
     * -Parameter storeResult: storeResult indicate whether the generated key pair should be stored in the database. This will primarily
     * be left as true, but testing code may set as false to generate a key pair for testing duplicate key protection.
     * If true, each key pair is stored in the database as Base64 encoded Strings of byte representations of the public
     * and private keys in PKCS#1 format.
     *
     * -Returns: KeyPair the private key of which is a 2048-bit RSA private key, and Data which is the key pair's interface id, a
     * SHA-256 hash of the PKCS#1 encoded byte representation of the public key.
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
     * Retrieves the persistently stored key pair associated with the given interface id, or returns null if not
     * present.
     *
     * -Parameter interfaceId: the interface id of the key pair, a SHA-256 hash of the PKCS#1 byte encoded representation of its public key.
     *
     * -Returns: KeyPair the private key of which  is a 2048-bit RSA key pair, and Data which is the key pair's interface id, a
     * SHA-256 hash of the PKCS#1 encoded byte representation of the public key.
     * -Returns: nil if no key pair is found with the given interface id
     */
    func getKeyPair(interfaceId: Data) throws -> KeyPair? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let dbKeyPair: DBKeyPair? = try dbService.getKeyPair(interfaceId: interfaceIdB64Str)
        if dbKeyPair != nil {
            let pubKeyBytes = Data(base64Encoded: dbKeyPair!.publicKey)!
            let privKeyBytes = Data(base64Encoded: dbKeyPair!.privateKey)!
            return try KeyPair(publicKeyBytes: pubKeyBytes, privateKeyBytes: privKeyBytes)
        } else {
            return nil
        }
    }
    
    /**
     * Persistently stores a public key associated with an interface id. This will generate a PKCS#1 byte
     * representation of the public key, encode it as a Base64 String and store it in the databse.
     *
     * -Parameter pubKey: the public key to be stored
     */
    func storePublicKey(pubKey: PublicKey) throws {
        let interfaceIdB64Str = pubKey.interfaceId.base64EncodedString()
        let pubKeyB64Str = try pubKey.toPkcs1Bytes().base64EncodedString()
        try dbService.storePublicKey(interfaceId: interfaceIdB64Str, publicKey: pubKeyB64Str)
    }
    
    /**
     * Retrieves the persistently stored public key associated with the given interface id, or returns null if not
     * present
     *
     * -Paramater interfaceId: the interface id of the public key, a SHA-256 hash of its PKCS#1 byte encoded
     * representation
     *
     * -Returns: PublicKey the public key of which is an RSA public key, and Data which is the public
     * key's interface id, a SHA-256 hash of its PKCS#1 byte encoded representation.
     * -Returns: nil if no public key is found with the given interface id
     */
    func getPublicKey(interfaceId: Data) throws -> PublicKey? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let dbPubKey: DBPublicKey? = try dbService.getPublicKey(interfaceId: interfaceIdB64Str)
        if dbPubKey != nil {
            let pubKeyBytes: Data = Data(base64Encoded: dbPubKey!.publicKey)!
            return try PublicKey(publicKeyBytes: pubKeyBytes)
        } else {
            return nil
        }
    }
}

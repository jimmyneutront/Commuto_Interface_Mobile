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
    
    //TODO: dedicated KeyPair and PublicKey class
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
     * -Returns: KeyPair the private key of which is a 2048-bit RSA private key, and the NSData is the key pair's interface id, which is a
     * SHA-256 hash of the PKCS#1 encoded byte representation of the public key.
     */
    func generateKeyPair(storeResult: Bool = true) throws -> KeyPair {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let privKeyBytes = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let interfaceId = interfIdFromPubKeyBytes(pubKeyBytes: pubKeyBytes)
        if storeResult {
            let interfaceIdB64Str = interfaceId.base64EncodedString(options: [])
            let pubKeyB64Str = (pubKeyBytes as NSData).base64EncodedString(options: [])
            let privKeyB64Str = (privKeyBytes as NSData).base64EncodedString(options: [])
            try dbService.storeKeyPair(interfaceId: interfaceIdB64Str, publicKey: pubKeyB64Str, privateKey: privKeyB64Str)
        }
        return try KeyPair(publicKey: publicKey, privateKey: privateKey)
    }
    
    /**
     * Retrieves the persistently stored key pair associated with the given interface id, or returns null if not
     * present.
     *
     * -Parameter interfaceId: the interface id of the key pair, a SHA-256 hash of the PKCS#1 byte encoded representation of its public key.
     *
     * -Returns: KeyPair the private key of which  is a 2048-bit RSA key pair, and the NSData is the key pair's interface id, which is a
     * SHA-256 hash of the PKCS#1 encoded byte representation of the public key.
     * -Returns: nil if no key pair is found with the given interface id
     */
    func getKeyPair(interfaceId: Data) throws -> KeyPair? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let dbKeyPair: DBKeyPair? = try dbService.getKeyPair(interfaceId: interfaceIdB64Str)
        if dbKeyPair != nil {
            let pubKeyBytes: NSData = NSData(base64Encoded: dbKeyPair!.publicKey, options: [])!
            let privKeyBytes: NSData = NSData(base64Encoded: dbKeyPair!.privateKey, options: [])!
            var keyOpts: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits as String: 2048]
            var error: Unmanaged<CFError>?
            guard let publicKey = SecKeyCreateWithData(pubKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            keyOpts[kSecAttrKeyClass as String] = kSecAttrKeyClassPrivate
            guard let privateKey = SecKeyCreateWithData(privKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return try KeyPair(publicKey: publicKey, privateKey: privateKey)
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
        var error: Unmanaged<CFError>?
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(pubKey.publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let interfaceId = interfIdFromPubKeyBytes(pubKeyBytes: pubKeyBytes)
        let interfaceIdB64Str = interfaceId.base64EncodedString(options: [])
        let pubKeyB64Str = (pubKeyBytes as NSData).base64EncodedString(options: [])
        try dbService.storePublicKey(interfaceId: interfaceIdB64Str, publicKey: pubKeyB64Str)
    }
    
    /**
     * Retrieves the persistently stored public key associated with the given interface id, or returns null if not
     * present
     *
     * -Paramater interfaceId: the interface id of the public key, a SHA-256 hash of its PKCS#1 byte encoded
     * representation
     *
     * -Returns: PublicKey the public key of which is an RSA public key, and the NSData is the public
     * key's interface id, which is a SHA-256 hash of its PKCS#1 byte encoded representation.
     * -Returns: nil if no public key is found with the given interface id
     */
    func getPublicKey(interfaceId: Data) throws -> PublicKey? {
        let interfaceIdB64Str = interfaceId.base64EncodedString()
        let dbPubKey: DBPublicKey? = try dbService.getPublicKey(interfaceId: interfaceIdB64Str)
        if dbPubKey != nil {
            let pubKeyBytes: NSData = NSData(base64Encoded: dbPubKey!.publicKey, options: [])!
            let keyOpts: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits as String: 2048]
            var error: Unmanaged<CFError>?
            guard let publicKey = SecKeyCreateWithData(pubKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return try PublicKey(publicKey: publicKey)
        } else {
            return nil
        }
    }
    
    /**
     Derives an interface id given the PKCS#1 byte encoded representation of an RSA public key.
     
     -Parameter pubKeyBytes: the PKCS#1 byte encoded representation of the key for which an interface id will be derived
     
     -Returns: the derived interface id, a SHA-256 hash of the public key's PKCS#1 byte encoded representation
     */
    func interfIdFromPubKeyBytes(pubKeyBytes: NSData) -> NSData {
        let interfaceIdDigest = SHA256.hash(data: pubKeyBytes as NSData)
        var interfaceIdByteArray = [UInt8]()
        for byte: UInt8 in interfaceIdDigest.makeIterator() {
            interfaceIdByteArray.append(byte)
        }
        let interfaceIdBytes = NSData(bytes: interfaceIdByteArray, length: interfaceIdByteArray.count)
        return interfaceIdBytes
    }
}

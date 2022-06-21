//
//  PublicKey.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 This is a wrapper around `CryptoKit`'s `SecKey`, with added support for Commuto Interface IDs. The wrapped key is the public key of a 2048-bit RSA private key, and the interface ID of a public key is the SHA-256 hash of its PKCS#1 formatted byte representation.
 
 - Properties:
    - interfaceId: The interface ID of this `PublicKey`, which is the SHA-256 hash of its PKCS#1 byte representation.
    - publicKey: The public RSA key that this `PublicKey` wraps, which is derived from a 2048-bit RSA private key.
 */
struct PublicKey {
    
    let interfaceId: Data
    let publicKey: SecKey
    
    /**
     Creates a `PublicKey` given the PKCS#1-formatted byte representation of a public key.
     
     - Parameter publicKeyBytes: The PKCS#1 bytes of the public key to be created, as `Data`.
     
     - Throws: An `Error` if key creation with the given bytes fails.
     */
    init(publicKeyBytes: Data) throws {
        //Restore public key
        let keyOpts: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        self.publicKey = publicKey
        
        //Restore interface id
        let interfaceIdDigest = SHA256.hash(data: publicKeyBytes as NSData)
        var interfaceIdByteArray = [UInt8]()
        for byte: UInt8 in interfaceIdDigest.makeIterator() {
            interfaceIdByteArray.append(byte)
        }
        let interfaceIdBytes = Data(bytes: interfaceIdByteArray, count: interfaceIdByteArray.count)
        self.interfaceId = interfaceIdBytes
    }
    
    /**
     Creates a new `PublicKey` using a public key as a `SecKey`.
     
     - Parameter publicKey: The public `SecKey` that this `PublicKey` wraps.
     
     - Throws: An `Error` if we are unable to compute the inteface ID of `publicKey`.
     */
    init(publicKey: SecKey) throws {
        self.publicKey = publicKey
        var error: Unmanaged<CFError>?
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let interfaceIdDigest = SHA256.hash(data: pubKeyBytes as NSData)
        var interfaceIdByteArray = [UInt8]()
        for byte: UInt8 in interfaceIdDigest.makeIterator() {
            interfaceIdByteArray.append(byte)
        }
        let interfaceIdBytes = Data(bytes: interfaceIdByteArray, count: interfaceIdByteArray.count)
        self.interfaceId = interfaceIdBytes
    }
    
    /**
     Verifies a signature using this `PublicKey`.
     
     - Parameters:
        - signedData: The bytes that have been signed, as `Data`.
        - signature: The signature of `signedData`.
     
     - Returns: A `Bool` indicating whether or not verification was successful.
     
     - Throws: An `Error` if we are unable to complete signature verification.
     */
    func verifySignature(signedData: Data, signature: Data) throws -> Bool {
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        var error: Unmanaged<CFError>?
        let success = SecKeyVerifySignature(publicKey, algorithm, signedData as CFData, signature as CFData, &error)
        if !success {
            throw error!.takeRetainedValue() as Error
        }
        return success
    }
    
    /**
     Encrypts the give bytes using this `PublicKey`, using OEAP SHA-256 padding.
     
     - Parameter clearData: The bytes to be encrypted, as `Data`.
     
     - Returns: `clearData` encrypted with this `KeyPair`'s public key.
     
     - Throws: An `Error` if encryption fails.
     */
    func encrypt(clearData: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let cipherData = SecKeyCreateEncryptedData(publicKey, algorithm, clearData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return cipherData
    }
    
    /**
     Encodes this `PublicKey` to its PKCS#1-formatted byte representation.
     
     - Returns: The PKCS#1 byte representation of this `PublicKey`, as `Data`.
     
     - Throws: An `Error` of encoding fails.
     */
    func toPkcs1Bytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(self.publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return pubKeyBytes as Data
    }
    
}

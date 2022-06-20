//
//  KeyPair.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import CryptoKit
import Foundation

/**
 This is a wrapper around `CryptoKit`'s `SecKey`, with added support for Commuto Interface IDs. The wrapped keys are a 2048-bit RSA private key and its corresponding public key.
 
 - Properties:
    - interfaceId: The interface ID of this `KeyPair`, which is the SHA-256 hash of the public key encoded in PKCS#1 byte format.
    - publicKey: The public RSA key derived from the 2048-bit RSA private key that this `KeyPair` wraps.
    - privateKey: The 2048-bit RSA private key that this `KeyPair` wraps.
 */
struct KeyPair {
    
    let interfaceId: Data
    let publicKey: SecKey
    let privateKey: SecKey
    
    /**
     Creates a `KeyPair`, which is wrapped around a new 2058-bit RSA private key and its public key.
     
     - Throws: An `Error` if key creation fails.
     */
    init() throws {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        try self.init(publicKey: SecKeyCopyPublicKey(privateKey)!, privateKey: privateKey)
    }
    
    /**
     Creates a `KeyPair` using the PKCS#1-formatted byte representation of a 2048-bit RSA private key and its public key.
     
     - Parameters:
        - publicKeyBytes: the PKCS#1 bytes of the public key of the key pair, as `Data`.
        - privateKeyBytes: the PKCS#1 bytes of the private key of the key pair. as `Data`.
     
     - Throws: An `Error` if key creation with the given bytes fails.
     */
    init(publicKeyBytes: Data, privateKeyBytes: Data) throws {
        //Restore keys
        var keyOpts: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic, kSecAttrKeySizeInBits as String: 2048]
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        keyOpts[kSecAttrKeyClass as String] = kSecAttrKeyClassPrivate
        guard let privateKey = SecKeyCreateWithData(privateKeyBytes as CFData, keyOpts as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        self.publicKey = publicKey
        self.privateKey = privateKey
        
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
     Creates a new `KeyPair` using a 2048-bit RSA private key as a `SecKey` and its public key, also as a `SecKey`.
     
     - Parameters:
        - publicKey: The public `SecKey` of the key pair.
        - privateKey: The private `SecKey` of the key pair.
     
     - Throws: An `Error` if we are not able to get a public key from the given private key.
     */
    init(publicKey: SecKey, privateKey: SecKey) throws {
        self.publicKey = publicKey
        self.privateKey = privateKey
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
     Signs bytes using this `KeyPair`'s private key.
     
     - Parameter data: The bytes to be signed, as `Data`.
     - Returns: The signature, as `Data`.
     
     - Throws: An `Error` if signature creation fails.
     */
    func sign(data: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return signature
    }
    
    /**
     Verifies a signature using this `KeyPair`'s public key.
     
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
     Encrypts the given bytes using this `KeyPair`'s public key, using OEAP SHA-256 padding.
     
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
     Decrypt the passed data using this KeyPair's RSA private key, using OEAP SHA-256 padding.
     - Parameter cipherData: the data to be decrypted
     - Returns Data: the decrypted data
     */
    /**
     Decrypts the given bytes using this `KeyPair`'s private key, using OEAP SHA-256 padding.
     
     - Parameter cipherData: The bytes to be decrypted, as `Data`.
     
     - Returns: `cipherData` decrypted with this `KeyPair`'s private key.
     
     - Throws: An `Error` if we are unable to complete the decryption process.
     */
    func decrypt(cipherData: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let clearData = SecKeyCreateDecryptedData(privateKey, algorithm, cipherData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return clearData
    }
    
    /**
     Encodes this `KeyPair`'s RSA public key to its PKCS#1-formatted byte representation.
     
     - Returns: The PKCS#1 byte representation of this `KeyPair`'s public key, as `Data`.
     
     - Throws: An `Error` if encoding fails.
     */
    func pubKeyToPkcs1Bytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(self.publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return pubKeyBytes as Data
    }
    
    /**
     Encodes this `KeyPair`'s 2048-bit RSA private key to its PKCS#-formatted byte representation.
     
     - Returns: The PKCS#1 byte representation of this `KeyPair`'s private key, as `Data`.
     
     - Throws: An `Error` if encoding fails.
     */
    func privKeyToPkcs1Bytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let privKeyBytes = SecKeyCopyExternalRepresentation(self.privateKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return privKeyBytes as Data
    }
    
}

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
 * The KeyPair struct is a wrapper around the SecKey class, with support for Commuto Interface IDs.
 * The wrapped keys shall be a 2048-bit RSA private key and its corresponding public key. interfaceId
 * is the SHA-256 hash of the key pair's public key encoded in PKCS#1 byte format.
 */
struct KeyPair {
    
    let interfaceId: Data
    let publicKey: SecKey
    let privateKey: SecKey
    
    /**
     Creates a KeyPair object wrapped around a new 2058-bit RSA private key and its public key
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
     Creates a KeyPair object using the PKCS#1 byte formats of a 2048-bit RSA private key and its public key
     - Parameters:
        - privateKeyBytes: the PKCS#1 bytes of the private key of the key pair
        - publicKeyBytes: the PKCS#1 bytes of the public key of the key pair
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
    Initializes a new KeyPair object, deriving interfaceId from the passed public key
     - Parameters:
        - publicKey: the public key of the key pair
        - privateKey: the private key of the key pair
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
     * Create a signature from the passed ByteArray using this KeyPair's private key
     *
     * - Parameter data: the data to be signed
     * - Returns Data: the signature
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
     * Verifies a signature using this KeyPair's public key
     *
     * - Parameter signedData: the data that was signed
     * - Parameter signature: the signature
     *
     * - Returns Boolean: indicating the success of the verification
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
     Encrypt the passed data using this KeyPair's RSA public key, using OEAP SHA-256 padding.
     - Parameter clearData: the data to be encrypted
     - Returns Data: the encrypted data
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
    func decrypt(cipherData: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let clearData = SecKeyCreateDecryptedData(privateKey, algorithm, cipherData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return clearData
    }
    
    /**
     Encodes the RSA public key to a PKCS#1 formatted byte representation
     - Returns Data: the public key's PKCS#1 byte representation
     */
    func pubKeyToPkcs1Bytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let pubKeyBytes = SecKeyCopyExternalRepresentation(self.publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return pubKeyBytes as Data
    }
    
    /**
     Encodes the 2048-bit RSA private key to a PKCS#1 formatted byte representation
     - Returns Data: the public key's PKCS#1 byte representation
     */
    func privKeyToPkcs1Bytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let privKeyBytes = SecKeyCopyExternalRepresentation(self.privateKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return privKeyBytes as Data
    }
    
}

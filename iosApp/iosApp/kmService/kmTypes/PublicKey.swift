//
//  PublicKey.swift
//  iosApp
//
//  Created by jimmyt on 11/28/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import CryptoKit
import Foundation

//TODO: static method to re-create public key from raw bytes

/**
 * The PublicKey class is a wrapper around the SecKey class, with support for Commuto Interface IDs.
 * The wrapped public key shall be that corresponding to a 2048-bit RSA private key key, and interfaceId
 * is the SHA-256 hash of the public key encoded in PKCS#1 byte format.
 */
struct PublicKey {
    
    let interfaceId: Data
    let publicKey: SecKey
    
    /**
        Initializes a new PublicKey object, deriving interfaceId from the passed public key
     - Parameter publicKey: the public key to be wrapped
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
     Encrypt the passed data using this PublicKey's RSA public key, using OEAP SHA-256 padding.
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
    
}

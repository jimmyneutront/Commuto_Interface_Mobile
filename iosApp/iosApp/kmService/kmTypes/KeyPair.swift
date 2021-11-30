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
    
    let interfaceId: NSData
    let publicKey: SecKey
    let privateKey: SecKey
    /**
        Initializes a new KeyPair object, deriving interfaceId from the passed public key
     - Parameters:
            -publicKey: the public key of the key pair
            -privateKey: the private key of the key pair
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
        let interfaceIdBytes = NSData(bytes: interfaceIdByteArray, length: interfaceIdByteArray.count)
        self.interfaceId = interfaceIdBytes
    }
    
    func encrypt(clearData: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let cipherData = SecKeyCreateEncryptedData(publicKey, algorithm, clearData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return cipherData
    }

    func decrypt(cipherData: Data) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let clearData = SecKeyCreateDecryptedData(privateKey, algorithm, cipherData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return clearData
    }
    
}

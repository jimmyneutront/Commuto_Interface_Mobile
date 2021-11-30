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
 * The PublicKey class is a wrapper around the SecKey class, with support for Commuto Interface IDs.
 * The wrapped public key shall be that corresponding to a 2048-bit RSA private key key, and interfaceId
 * is the SHA-256 hash of the public key encoded in PKCS#1 byte format.
 */
struct PublicKey {
    
    let interfaceId: NSData
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
        let interfaceIdBytes = NSData(bytes: interfaceIdByteArray, length: interfaceIdByteArray.count)
        self.interfaceId = interfaceIdBytes
    }
    
    func encryptWithPublicKey(clearData: Data) throws -> Data? {
        let algorithm: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
        var error: Unmanaged<CFError>?
        guard let cipherData = SecKeyCreateEncryptedData(publicKey, algorithm, clearData as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return cipherData
    }
    
}

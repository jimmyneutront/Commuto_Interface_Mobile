//
//  SymmetricKey.swift
//  iosApp
//
//  Created by jimmty on 12/2/21.
//  Copyright © 2021 orgName. All rights reserved.
//

import CryptoSwift
import Foundation

/**
 * The SymmetricKey struct contains an AES-256 key, with methods for encrypting and decrypting data using the key.
 *
 * - Parameter keyBytes: the AES-256 key in byte array format
 * - Parameter keyData: the AES-256 key in Data format
 */
struct SymmetricKey {
    let keyBytes: [UInt8]
    let keyData: Data
    
    init(key: [UInt8]) {
        self.keyBytes = key
        self.keyData = Data(keyBytes)
    }
    
    init(key: Data) {
        self.keyData = key
        self.keyBytes = key.bytes
    }

    /**
     * Encrypt data with this key using CBC with PKCS5 padding.
     *
     * - Parameter data: the data to be encrypted
     * - Returns SymmetricallyEncryptedData: the encrypted data along with the initialization vector used.
     */
    func encrypt(data: Data) throws -> SymmetricallyEncryptedData {
        let iv: [UInt8] = AES.randomIV(AES.blockSize)
        let aes = try AES(key: keyBytes, blockMode: CBC(iv: iv), padding: .pkcs5)
        let encryptedBytes = try aes.encrypt(data.bytes)
        return SymmetricallyEncryptedData(data: encryptedBytes, iv: iv)
    }
    
    /**
     * Decrypt data encrypted using CBC with PKCS5 padding with this key.
     *
     * - Parameter data: the SymmetricallyEncryptedData object containing both the encrypted data and the initialization
     * vector used.
     * - Returns Data: the decrypted data
     */
    func decrypt(data: SymmetricallyEncryptedData) throws -> Data {
        let aes = try AES(key: keyBytes, blockMode: CBC(iv: data.initializationVectorBytes), padding: .pkcs5)
        return Data(try aes.decrypt(data.encryptedDataBytes))
    }
}

/**
 * The SymmetricallyEncryptedData struct contains symmetrically encrypted data and the initialization vector used to encrypt it.
 *
 * - Parameter encryptedData: symmetrically encrypted data
 * - Parameter iv: the initialization vector used to encrypt encryptedData
 */
struct SymmetricallyEncryptedData {
    let encryptedDataBytes: [UInt8]
    let encryptedData: Data
    
    let initializationVectorBytes: [UInt8]
    let initializationVectorData: Data
    
    init(data: [UInt8], iv: [UInt8]) {
        self.encryptedDataBytes = data
        self.initializationVectorBytes = iv
        
        self.encryptedData = Data(encryptedDataBytes)
        self.initializationVectorData = Data(initializationVectorBytes)
    }
    
    init(data: Data, iv: Data) {
        self.encryptedDataBytes = data.bytes
        self.initializationVectorBytes = iv.bytes
        
        self.encryptedData = data
        self.initializationVectorData = iv
    }
}

/**
 Thrown when newSymmetricKey() encounters an error generating random bytes
 */
enum SymmetricKeyError: Error {
    case creationError(message: String)
}

/**
 * Returns a new SymmetricKey object wrapped around an AES-256 key.
 */
func newSymmetricKey() throws -> SymmetricKey {
    var keyBytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, keyBytes.count, &keyBytes)
    if status != errSecSuccess {
        throw SymmetricKeyError.creationError(message: "Unexpected error generating random bytes")
    }
    return SymmetricKey(key: keyBytes)
}

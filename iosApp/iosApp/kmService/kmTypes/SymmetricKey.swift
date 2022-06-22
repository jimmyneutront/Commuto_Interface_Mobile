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
 This is an AES-256 key, with functions for encryption and decryption.
 
 - Properties:
    - keyBytes: The AES-256 key in byte array format.
    - keyData: The AES-256 key as `Data`.
 */
struct SymmetricKey {
    let keyBytes: [UInt8]
    let keyData: Data
    
    /**
     Creates a new `SymmetricKey` given an AES-256 key as a byte array.
     
     - Parameter key: The AES-256 key to be created, as a byte array.
     */
    init(key: [UInt8]) {
        self.keyBytes = key
        self.keyData = Data(keyBytes)
    }
    
    /**
     Creates a new `SymmetricKey` given an AES-256 key as `Data`.
     
     - Parameter key: The AES-256 key to be created, as `Data`.
     */
    init(key: Data) {
        self.keyData = key
        self.keyBytes = key.bytes
    }
    
    /**
     Creates a new initialization vector and then performs AES encryption on the given bytes with this `SymmetricKey` using CBC with PKCS#5 padding.
     
     - Parameter data: The bytes to be encrypted, as `Data`.
     
     - Returns `SymmetricallyEncryptedData`, containing a new initialization vector and `data` encrypted with this `SymmetricKey` and the new initialization vector.
     
     - Throws An `Error` if AES encryption fails.
     */
    func encrypt(data: Data) throws -> SymmetricallyEncryptedData {
        let iv: [UInt8] = AES.randomIV(AES.blockSize)
        let aes = try AES(key: keyBytes, blockMode: CBC(iv: iv), padding: .pkcs5)
        let encryptedBytes = try aes.encrypt(data.bytes)
        return SymmetricallyEncryptedData(data: encryptedBytes, iv: iv)
    }

    /**
     Decrypts `SymmetricallyEncryptedData` that has been AES encrypted with this `SymmetricKey` using CBC with PKCS#5 padding.
     
     - Parameter data: The `SymmetricallyEncryptedData` to be decrypted, which contains the cipher data to be decrypted and the initialization vector used to decrypt the cipher data.
     
     - Returns: The cipher data in the passed `SymmetricallyEncryptedData` decrypted with the initialization vector in the passed `SymmetricallyEncryptedData` and this `SymmetricKey`, as `Data`.
     
     - Throws: An `Error` if AES decryption fails.
     */
    func decrypt(data: SymmetricallyEncryptedData) throws -> Data {
        let aes = try AES(key: keyBytes, blockMode: CBC(iv: data.initializationVectorBytes), padding: .pkcs5)
        return Data(try aes.decrypt(data.encryptedDataBytes))
    }
}

#warning("TODO: move this to its own file")
/**
 Contains data encrypted with a `SymmetricKey` and the initialization vector used to encrypt it.
 */
struct SymmetricallyEncryptedData {
    /**
     The encrypted data, as a byte array.
     */
    let encryptedDataBytes: [UInt8]
    /**
     The encrypted data as `Data`.
     */
    let encryptedData: Data
    
    /**
     The initialization vector used to encrypt this `SymmetricallyEncryptedData`, as a byte array.
     */
    let initializationVectorBytes: [UInt8]
    /**
     The initialization vector used to encrypt this `SymmetricallyEncryptedData`, as `Data`.
     */
    let initializationVectorData: Data
    
    /**
     Creates a new `SymmetricallyEncryptedData` given encrypted data and the initialization vector used to encrypt it, both as byte arrays.
     
     - Parameters:
        - data: The encrypted data, as a byte array.
        - iv: The initialization vector used to encrypt `data`, as a byte array.
     */
    init(data: [UInt8], iv: [UInt8]) {
        self.encryptedDataBytes = data
        self.initializationVectorBytes = iv
        
        self.encryptedData = Data(encryptedDataBytes)
        self.initializationVectorData = Data(initializationVectorBytes)
    }
    
    /**
     Creates a new `SymmetricallyEncryptedData` given encrypted data and the initialization vector used to encrypt it, both as `Data`.
     
     - Parameters:
        - data: The encrypted data, as `Data`.
        - iv: The initialization vector used to encrypt `data`, as `Data`.
     */
    init(data: Data, iv: Data) {
        self.encryptedDataBytes = data.bytes
        self.initializationVectorBytes = iv.bytes
        
        self.encryptedData = data
        self.initializationVectorData = iv
    }
}

/**
 An `Error` thrown when `newSymmetricKey()` encounters an `Error` while generating random bytes.
 */
enum SymmetricKeyError: Error {
    #warning("TODO: rename message as desc")
    /**
     Thrown when `newSymmetricKey()` encounters an error while generating random bytes to create a new `SymmetricKey`.
     
     - Parameter message: A `String` that provides information about the context in which the error was thrown.
     */
    case creationError(message: String)
}

#warning("TODO: make this a no-argument constructor of SymmetricKey")
/**
 Creates a new `SymmetricKey` wrapped around a new AES-256 key.
 
 - Returns: A new `SymmetricKey`.
 
 - Throws: A `SymmetricKeyError.creationError` if key creation fails.
 */
func newSymmetricKey() throws -> SymmetricKey {
    var keyBytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, keyBytes.count, &keyBytes)
    if status != errSecSuccess {
        throw SymmetricKeyError.creationError(message: "Unexpected error generating random bytes")
    }
    return SymmetricKey(key: keyBytes)
}
